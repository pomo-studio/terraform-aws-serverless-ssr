# Lambda Functions for SSR - Primary and DR regions

# Bootstrap Lambda Code
# This creates a minimal Lambda package so infrastructure can be created
# without requiring a pre-built application. The real app code is deployed later.
# ------------------------------------------------------------------------------

# Create bootstrap Lambda code inline
locals {
  bootstrap_code = <<-EOF
    exports.handler = async (event, context) => {
      const path = event.rawPath || event.path || '/';
      
      // Health check endpoint
      if (path === '/api/health') {
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ 
            status: 'bootstrap', 
            message: 'Lambda initialized - awaiting application deployment',
            timestamp: new Date().toISOString()
          })
        };
      }
      
      // Default response for all other paths
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'text/html' },
        body: `<!DOCTYPE html>
    <html>
    <head><title>$${var.project_name}</title></head>
    <body>
      <h1>$${var.project_name}</h1>
      <p>Serverless SSR Platform - Bootstrap Mode</p>
      <p>Infrastructure is ready. Deploy your application to see content.</p>
      <p>Health check: <a href="/api/health">/api/health</a></p>
    </body>
    </html>`
      };
    };
  EOF
}

# Create archive from inline code
data "archive_file" "bootstrap" {
  type        = "zip"
  output_path = "${path.module}/bootstrap.zip"

  source {
    content  = local.bootstrap_code
    filename = "index.js"
  }

  # Add package.json to specify CommonJS for Node.js 22 compatibility
  source {
    content = jsonencode({
      type = "commonjs"
    })
    filename = "package.json"
  }
}

# Upload bootstrap code to S3 (Primary)
resource "aws_s3_object" "bootstrap_primary" {
  provider = aws.primary

  bucket = aws_s3_bucket.lambda_deployments_primary.id
  key    = "lambda/function.zip"
  source = data.archive_file.bootstrap.output_path
  etag   = data.archive_file.bootstrap.output_md5
}

# Upload bootstrap code to S3 (DR) - if enabled
resource "aws_s3_object" "bootstrap_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  bucket = aws_s3_bucket.lambda_deployments_dr[count.index].id
  key    = "lambda/function.zip"
  source = data.archive_file.bootstrap.output_path
  etag   = data.archive_file.bootstrap.output_md5
}

# Primary Region Lambda
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "primary" {
  provider = aws.primary

  function_name = "${local.app_name}-primary"
  description   = "${var.project_name} - Primary Region (${var.primary_region})"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  # Use bootstrap code from S3
  s3_bucket = aws_s3_bucket.lambda_deployments_primary.id
  s3_key    = "lambda/function.zip"

  # Ensure bootstrap code is uploaded first
  depends_on = [aws_s3_object.bootstrap_primary]

  environment {
    variables = local.lambda_environment
  }

  tags = local.common_tags

  lifecycle {
    # Ignore changes to S3 code - app deployment updates this outside Terraform
    ignore_changes = [
      s3_bucket,
      s3_key,
      s3_object_version,
    ]
  }
}

# DR Region Lambda
# ------------------------------------------------------------------------------

resource "aws_lambda_function" "dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  function_name = "${local.app_name}-dr"
  description   = "${var.project_name} - DR Region (${var.dr_region})"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  # Use bootstrap code from S3
  s3_bucket = aws_s3_bucket.lambda_deployments_dr[0].id
  s3_key    = "lambda/function.zip"

  # Ensure bootstrap code is uploaded first
  depends_on = [aws_s3_object.bootstrap_dr]

  environment {
    variables = local.lambda_environment
  }

  tags = local.common_tags

  lifecycle {
    # Ignore changes to S3 code - app deployment updates this outside Terraform
    ignore_changes = [
      s3_bucket,
      s3_key,
      s3_object_version,
    ]
  }
}

# Lambda Environment Variables
# ------------------------------------------------------------------------------

locals {
  lambda_environment = merge(
    {
      NODE_ENV       = "production"
      NITRO_PRESET   = "aws-lambda"
      PRIMARY_REGION = var.primary_region
      DR_REGION      = var.dr_region
      PROJECT_NAME   = var.project_name
    },
    var.enable_dynamo ? { DYNAMODB_TABLE = aws_dynamodb_table.visits_primary[0].name } : {}
  )
}

# IAM Role for Lambda Execution
# ------------------------------------------------------------------------------

resource "aws_iam_role" "lambda_execution" {
  provider = aws.primary
  name     = "${local.app_name}-lambda-role"

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

  tags = local.common_tags
}

# IAM Policy for DynamoDB Access
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_dynamodb" {
  count    = var.enable_dynamo ? 1 : 0
  provider = aws.primary
  name     = "${local.app_name}-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.visits_primary[0].arn,
          "${aws_dynamodb_table.visits_primary[0].arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for S3 Access (Lambda needs to read deployment packages)
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_s3" {
  provider = aws.primary
  name     = "${local.app_name}-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = concat([
          "${aws_s3_bucket.lambda_deployments_primary.arn}/lambda/*"
        ], var.enable_dr ? ["${aws_s3_bucket.lambda_deployments_dr[0].arn}/lambda/*"] : [])
      }
    ]
  })

  tags = local.common_tags
}

# Attach Policies to Lambda Role
# ------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  count      = var.enable_dynamo ? 1 : 0
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_dynamodb[0].arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_s3.arn
}

# Lambda Function URLs
# ------------------------------------------------------------------------------

resource "aws_lambda_function_url" "primary" {
  provider = aws.primary

  function_name      = aws_lambda_function.primary.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    max_age           = 86400
  }
}

resource "aws_lambda_function_url" "dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  function_name      = aws_lambda_function.dr[0].function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    max_age           = 86400
  }
}

# Lambda Permissions for Function URL Access
# ------------------------------------------------------------------------------

resource "aws_lambda_permission" "allow_function_url_primary" {
  provider = aws.primary

  statement_id  = "AllowFunctionURLInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.primary.function_name
  principal     = "*"
}

resource "aws_lambda_permission" "allow_function_url_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  statement_id  = "AllowFunctionURLInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dr[0].function_name
  principal     = "*"
}
