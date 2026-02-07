# Lambda Module - Reusable Lambda function with Function URL

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = var.role_arn != "" ? var.role_arn : aws_iam_role.lambda[0].arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  memory_size   = var.memory_size
  timeout       = var.timeout

  # Deployment package from S3
  s3_bucket = var.s3_bucket
  s3_key    = var.s3_key

  # Source code hash for triggering updates
  source_code_hash = var.source_code_hash

  environment {
    variables = var.environment_variables
  }

  # VPC configuration (optional)
  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != [] ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tags = var.tags
}

# IAM Role for Lambda (if not provided)
resource "aws_iam_role" "lambda" {
  count = var.role_arn == "" ? 1 : 0
  name  = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# Attach basic execution role
resource "aws_iam_role_policy_attachment" "basic_execution" {
  count      = var.role_arn == "" ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
