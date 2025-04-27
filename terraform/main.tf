provider "aws" {
  region = "ap-south-1"  # Update with your preferred AWS region
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami           = "ami-03bb6d83c60fc5f7c"  # Amazon Linux 2 AMI in Mumbai
  instance_type = "t2.micro"               # Update instance type if needed
  key_name      = "kalki"                  # Replace with your EC2 key pair name

  # Correct way to assign a security group (list of strings)
  security_groups = ["sg-05ceab0bf868a0434"]  # This should be in a list

  associate_public_ip_address = true  # Automatically associate public IP

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
  runtime       = "nodejs18.x"   # Updated runtime
  timeout       = 30
  filename      = "lambda.zip"   # Lambda function package (must exist before applying)
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  alarm_name          = "EC2StatusCheckFailed"
  comparison_operator = "LessThanThreshold"  # Fixed the comparison_operator
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
