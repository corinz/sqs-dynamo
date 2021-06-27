terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 1"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Create SQS
resource "aws_sqs_queue" "queue" {
  name       = "queue"
  fifo_queue = false
}

# Create Policy for API Gateway to SQS integration
resource "aws_iam_policy" "sqs" {
  name        = "SQSwrite"
  path        = "/"
  description = "SQSwrite"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility",
          "sqs:ListDeadLetterSourceQueues",
          "sqs:SendMessageBatch",
          "sqs:PurgeQueue",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:CreateQueue",
          "sqs:ListQueueTags",
          "sqs:ChangeMessageVisibilityBatch",
          "sqs:SetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.queue.arn
      },
    ]
  })
}

# Create Role for API Gateway
resource "aws_iam_role" "apigw" {
  name = "apigw"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })
}

# Attach API Gateway Role and SQS Policy
resource "aws_iam_role_policy_attachment" "apigw-sqs" {
  role       = aws_iam_role.apigw.name
  policy_arn = aws_iam_policy.sqs.arn
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "apigw" {
  name = "apigw"
}

resource "aws_api_gateway_resource" "notify" {
  parent_id   = aws_api_gateway_rest_api.apigw.root_resource_id
  path_part   = "notify"
  rest_api_id = aws_api_gateway_rest_api.apigw.id
}

resource "aws_api_gateway_method" "notify" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.notify.id
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
}

resource "aws_api_gateway_integration" "apigw" {
  http_method             = aws_api_gateway_method.notify.http_method
  resource_id             = aws_api_gateway_resource.notify.id
  rest_api_id             = aws_api_gateway_rest_api.apigw.id
  type                    = "AWS"
  integration_http_method = "POST"
  credentials             = aws_iam_role.apigw.arn
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.queue.name}"
  passthrough_behavior    = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = <<EOF
Action=SendMessage&MessageBody=$input.body
    EOF
  }
  depends_on = [
    aws_iam_role_policy_attachment.apigw-sqs
  ]

}

resource "aws_api_gateway_deployment" "apigw" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.notify.id,
      aws_api_gateway_method.notify.id,
      aws_api_gateway_integration.apigw.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.apigw.id
  rest_api_id   = aws_api_gateway_rest_api.apigw.id
  stage_name    = "v1"
}

resource "aws_api_gateway_method_response" "OK" {
  rest_api_id = aws_api_gateway_rest_api.apigw.id
  resource_id = aws_api_gateway_resource.notify.id
  http_method = aws_api_gateway_method.notify.http_method
  status_code = 200
}

resource "aws_api_gateway_integration_response" "OK" {
  rest_api_id       = aws_api_gateway_rest_api.apigw.id
  resource_id       = aws_api_gateway_resource.notify.id
  http_method       = aws_api_gateway_method.notify.http_method
  status_code       = aws_api_gateway_method_response.OK.status_code
  selection_pattern = "^2[0-9][0-9]" # 200

  depends_on = [
    aws_api_gateway_integration.apigw
  ]
}

# DynamoDB
resource "aws_dynamodb_table" "SQSmessages" {
  name           = "SQSmessages"
  billing_mode   = "PROVISIONED"
  hash_key       = "Id"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "Id"
    type = "S"
  }
}

resource "aws_iam_policy" "dynamodb" {
  name        = "dynamodb"
  path        = "/"
  description = "dynamodbWrite"

  policy = jsonencode({
    Version : "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
      ]
      Resource = aws_dynamodb_table.SQSmessages.arn
      },
  ] })
}

resource "aws_iam_policy" "SQSReceiveMessage" {
  name        = "SQSReceiveMessage"
  path        = "/"
  description = "SQSReceiveMessage"

  policy = jsonencode({
    Version : "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "*"
      },
  ] })
}

resource "aws_iam_role" "lambda" {
  name = "lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.dynamodb.arn
}

resource "aws_iam_role_policy_attachment" "SQSReceiveMessage" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.SQSReceiveMessage.arn
}

#Lambda
resource "aws_lambda_function" "lambda" {
  filename        = "app.zip"
  function_name = "getandstoremessages"
  role          = aws_iam_role.lambda.arn
  source_code_hash = filebase64sha256("app.zip")
  handler = "dbWrite.handler"
  runtime = "nodejs14.x"
}

resource "aws_lambda_event_source_mapping" "source-map" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.lambda.arn
  batch_size = 5
}