provider "aws" {
  region = "ap-south-1"  # Update with your preferred AWS region
}

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {   # ✅ Added this block to avoid revoke errors
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = "ami-03bb6d83c60fc5f7c"  # Amazon Linux 2 AMI in Mumbai
  instance_type          = "t2.micro"
  key_name               = "kalki"

  # Correct way when security group is created by Terraform
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  associate_public_ip_address = true

  tags = {
    Name = "AutoHealingEC2"
  }

  monitoring = true
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

# CloudWatch Alarm for EC2 Status Check
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

# IAM Policy for CloudWatch Logs permissions
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "CloudWatchLogsPolicy"
  description = "Policy to allow Lambda to create log groups, log streams, and put log events."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}


# Output EC2 Instance ID
output "ec2_instance_id" {
  value = aws_instance.web_server.id
}
