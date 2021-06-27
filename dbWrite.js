var AWS = require('aws-sdk');
AWS.config.update({region: 'us-east-1'});

const crypto = require("crypto");
var ddb = new AWS.DynamoDB({apiVersion: '2012-08-10'});

exports.handler = async function(event, context) {
    event.Records.forEach(record => {
      const { body } = record;
      console.log(body);
      var id = crypto.randomBytes(16).toString("hex")
      var params = {
        TableName: 'SQSmessages',
        Item: {
          'Id' : {S: id},
          'message' : {S: body}
        }
      };
      
      // Call DynamoDB to add the item to the table
      ddb.putItem(params, function(err, data) {
        if (err) {
          console.log("Error", err);
        } else {
          console.log("Success", data);
        }
      })
    });
    return {};
};