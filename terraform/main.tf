provider "aws" {
  region = "ap-south-1"  # Update with your preferred AWS region
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami             = "ami-0c55b159cbfafe1f0"  # Replace with your desired AMI ID
  instance_type   = "t2.micro"               # Update instance type if needed
  key_name        = "kalki"                  # Replace with your EC2 key pair name
  security_groups = ["your-security-group"]  # Replace with your security group name

  tags = {
    Name = "AutoHealingEC2"
  }

  monitoring = true  # Enable detailed monitoring (required for CloudWatch)
}

# Data block for IAM Policy Document (for Lambda AssumeRole)
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Lambda Function for Self-Healing
resource "aws_lambda_function" "self_healing_lambda" {
  function_name = "SelfHealingEC2Lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  timeout       = 30
  filename      = "lambda.zip"  # Lambda function package (must exist before applying)
}

# CloudWatch Alarm to trigger Lambda if EC2 status check fails
resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "EC2StatusCheckFailed"
  comparison_operator = "LESS_THAN_THRESHOLD"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "Triggered if EC2 status check fails"
  
  dimensions = {
    InstanceId = aws_instance.web_server.id
  }

  alarm_actions = [
    aws_lambda_function.self_healing_lambda.arn
  ]
}

# Output
output "ec2_instance_id" {
  value = aws_instance.web_server.id
}
