const AWS = require('aws-sdk');
const ec2 = new AWS.EC2();

exports.handler = async (event) => {
  const instanceId = event.detail.instanceId;  // Instance ID from the CloudWatch Alarm

  const params = {
    InstanceIds: [instanceId],
  };

  try {
    // Stop the EC2 instance
    console.log(`Stopping instance ${instanceId}`);
    await ec2.stopInstances(params).promise();

    // Start the EC2 instance
    console.log(`Starting instance ${instanceId}`);
    await ec2.startInstances(params).promise();

    return {
      statusCode: 200,
      body: JSON.stringify('Instance restarted successfully'),
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify('Failed to restart the instance'),
    };
  }
};
