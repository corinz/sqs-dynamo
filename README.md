Design
======
We have 4 AWS services in play. API Gateway serves the frontend/supplies our endpoint. API Gateway serves the payload to SQS which invokes a Lambda function to commit the message payload to DynamoDB.

Rationale for these services:
- API Gateway because of the ability to expand the API and the web-facing freebies you get like TLS and throttling
- SQS because it prevents data loss, downtime when an app crashes
- Lambda because the app is simple and doesn't always have to be running since SQS triggers the job. Much more affordable than EC2 or ECS, especially at low volume
- DynamoDB because a NoSQL DB is fast, scalable, and easily configured for simple payloads and potentially large and expanding datasets

My rationale for AWS SaaS heavy approach versus EC2/ECS/EKS/ALB/R53: 
1. We aren't _responding_ to the real-time incidents, only logging them. This means...
2. A slower time to log each incident due to many AWS services is OK
3. This is not a rapidly changing project, so the pre-canned solutions from AWS will suite this app well for years to come without making major changes
4. Nearly the entire app can be deployed & updated with changes to `main.tf` and a `terraform apply`
5. As far as cloud based solutions go -- this is a cheap implementation
6. And of course, every AWS product included can perform at scale
7. And you get a bunch of freebies, TLS, request throttling, redundancy

Application URL: https://q4x0a6ucc6.execute-api.us-east-1.amazonaws.com/v1/notify

Usage:
1. `terraform apply`
2. 
`
curl \
  --header "Content-Type: application/json" \
  --request POST \
  --data '{"payload":"example"}' \
https://q4x0a6ucc6.execute-api.us-east-1.amazonaws.com/v1/notify
`

Some TODOs/things I couldn't get to

Terraform
- TF deployment is currently a single file... simple to read, but not great to maintain
- Remove in-line AWS policies from Terraform resources and place in dedicated directory

Front End
- POST request to front end (API Gateway) doesn't return meaningful response
- Add authentication to the front-end, currently the endpoint is exposed to any user

Payload/DB
- Expand the use of DynamoDB by creating attributes that align with the expected payload instead of jamming the entire payload into a single attribute. This would decrease post-processing efforts down-stream
- Enforce the defined payload stucture and reject anything else with meaningful errors
- Append useful params to the payload before comitting, e.g. uuid, date/time received

SQS
- Consider SQS FIFO for its guaranteed one-time delivery

Logging
- There isn't any.




Background
==========
911 emergency incident data are sent in nation wide in realtime so that we can provide better analytics to improve fire department operations and public safety.

Task
----
Design a cloud based system for ingesting, enriching, and storing 911 incident data so that they can be used for analytics.

Notes
-----
* Each incident will come in as a json.
* Example incidents are provided in the data folder.
* In some cases an incident may unfold over an extended period of time (example: neighborhood burning due to wildfire) in which case the updated incident will be sent in multiple times.
* Assume AWS infrastructure.
* Please use AWS free tier or resources with minimal costs to make it practical for both your development and our evaluation.
* We would like you to try to spend up to 4 hours. It is okay if you spend less time or more time but we would like your response within 24 hours of receiving the email.
* We understand that this is an open ended project and different engineers may have very different takes on what the deliverable looks like, and that is okay.

## Hints
* There are _many_ correct ways to complete this task
* We do not expect a Production-quality deliverable for this exercise. For some tasks, it may be sufficient to add appropriate comments of the nature _"In a real, Production system, I would additionally do this..."_
* We recognize that spending only four (4) hours means that you can only work on a limited implemention which is likely far from everything that you would like to do. Part of the exercise involves using your good judgment regarding what you actually _will_ implement. 
* You are absolutely free to spend more than 4 hours if you like (there is no penalty for doing so), but the completed project must be checked-in with 24 hours
* The most important criterion for evaluation is whether your project actually works. Whatever is delivered must be runnable. A project with a smaller amount of work that actually runs is far more valuable than a larger project that does not work or does not work correctly.
* Do not become discouraged. Only candidates whom we believe will be successful are advanced to this stage of the recruiting process. You can do this!


Deliverable
-----------
* Link to a github repository which contains everything you are submitting with your commits as you originally made them.
* Brief explanation of the design, reasoning behind it, and if needed, which parts of the design are covered in what you are submitting.
* Include your "production" infrastructure as code and anything else that you submit with it.
* Steps for someone who is not necessarily a devops engineer but technical enough to follow them.
* Assume the user will be running your steps on a clean centos-7.3 they setup locally.
* Couple of screenshots that show your project working.
