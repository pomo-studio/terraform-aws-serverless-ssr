# CI/CD IAM User and Policies
# Dedicated user for GitHub Actions deployments with least-privilege access

locals {
  cicd_dynamodb_statement = var.enable_dynamo ? [{
    Sid    = "DynamoDBOperations"
    Effect = "Allow"
    Action = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DescribeTable"
    ]
    Resource = [
      aws_dynamodb_table.visits_primary[0].arn,
      "${aws_dynamodb_table.visits_primary[0].arn}/*"
    ]
  }] : []
}

# CI/CD IAM User
resource "aws_iam_user" "cicd" {
  count    = var.create_ci_cd_user ? 1 : 0
  provider = aws.primary
  name     = "${local.app_name}-cicd"
  path     = "/ci-cd/"

  tags = merge(local.common_tags, {
    Purpose     = "GitHub Actions CI/CD"
    Environment = var.environment
  })
}

# CI/CD IAM Policy - Least privilege for deployment tasks
resource "aws_iam_policy" "cicd" {
  count       = var.create_ci_cd_user ? 1 : 0
  provider    = aws.primary
  name        = "${local.app_name}-cicd-policy"
  path        = "/ci-cd/"
  description = "Least-privilege policy for ${local.app_name} CI/CD deployments"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "LambdaDeployment"
          Effect = "Allow"
          Action = [
            "lambda:UpdateFunctionCode",
            "lambda:GetFunction",
            "lambda:GetFunctionUrlConfig",
            "lambda:InvokeFunction",
            "lambda:PublishVersion"
          ]
          Resource = [
            "arn:aws:lambda:${var.primary_region}:${data.aws_caller_identity.current.account_id}:function:${local.app_name}-*",
            "arn:aws:lambda:${var.dr_region}:${data.aws_caller_identity.current.account_id}:function:${local.app_name}-*"
          ]
        },
        {
          Sid    = "S3DeploymentArtifacts"
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = concat([
            aws_s3_bucket.lambda_deployments_primary.arn,
            "${aws_s3_bucket.lambda_deployments_primary.arn}/*",
            aws_s3_bucket.static_assets.arn,
            "${aws_s3_bucket.static_assets.arn}/*"
            ], var.enable_dr ? [
            aws_s3_bucket.lambda_deployments_dr[0].arn,
            "${aws_s3_bucket.lambda_deployments_dr[0].arn}/*",
            aws_s3_bucket.static_assets_dr[0].arn,
            "${aws_s3_bucket.static_assets_dr[0].arn}/*"
          ] : [])
        },
        {
          Sid    = "CloudFrontRead"
          Effect = "Allow"
          Action = [
            "cloudfront:ListDistributions"
          ]
          Resource = "*"
        },
        {
          Sid    = "CloudFrontInvalidation"
          Effect = "Allow"
          Action = [
            "cloudfront:CreateInvalidation",
            "cloudfront:GetInvalidation",
            "cloudfront:ListInvalidations"
          ]
          Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.main.id}"
        },
        {
          Sid    = "ReadOnlyForVerification"
          Effect = "Allow"
          Action = [
            "logs:DescribeLogGroups",
            "logs:FilterLogEvents"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "aws:RequestedRegion" = [var.primary_region, var.dr_region]
            }
          }
        }
      ],
      local.cicd_dynamodb_statement
    )
  })
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "cicd" {
  count      = var.create_ci_cd_user ? 1 : 0
  provider   = aws.primary
  user       = aws_iam_user.cicd[0].name
  policy_arn = aws_iam_policy.cicd[0].arn
}

# Create access key for the CI/CD user
# NOTE: This creates a long-term credential. For production, consider using
# GitHub OIDC federation instead (see iam-oidc.tf for alternative)
resource "aws_iam_access_key" "cicd" {
  count    = var.create_ci_cd_user ? 1 : 0
  provider = aws.primary
  user     = aws_iam_user.cicd[0].name
}

# Store access key in AWS Secrets Manager for secure retrieval
resource "aws_secretsmanager_secret" "cicd_credentials" {
  count       = var.create_ci_cd_user ? 1 : 0
  provider    = aws.primary
  name        = "${local.app_name}/cicd-credentials"
  description = "CI/CD user credentials for GitHub Actions"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "cicd_credentials" {
  count     = var.create_ci_cd_user ? 1 : 0
  provider  = aws.primary
  secret_id = aws_secretsmanager_secret.cicd_credentials[0].id

  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.cicd[0].id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.cicd[0].secret
    AWS_ACCOUNT_ID        = data.aws_caller_identity.current.account_id
    USER_ARN              = aws_iam_user.cicd[0].arn
  })
}

# Output instructions (sensitive values are marked)
output "cicd_user_name" {
  description = "Name of the CI/CD IAM user"
  value       = var.create_ci_cd_user ? aws_iam_user.cicd[0].name : null
}

output "cicd_user_arn" {
  description = "ARN of the CI/CD IAM user"
  value       = var.create_ci_cd_user ? aws_iam_user.cicd[0].arn : null
}

output "cicd_credentials_secret" {
  description = "AWS Secrets Manager ARN containing CI/CD credentials"
  value       = var.create_ci_cd_user ? aws_secretsmanager_secret.cicd_credentials[0].arn : null
}

output "cicd_access_key_id" {
  description = "Access Key ID for CI/CD user (retrieve secret from Secrets Manager)"
  value       = var.create_ci_cd_user ? aws_iam_access_key.cicd[0].id : null
}

# Instructions for retrieving credentials
output "cicd_setup_instructions" {
  description = "Instructions for setting up CI/CD credentials"
  value       = var.create_ci_cd_user ? format("CI/CD User: %s\nSecret: %s", aws_iam_user.cicd[0].name, aws_secretsmanager_secret.cicd_credentials[0].name) : "CI/CD user not created (create_ci_cd_user = false)"
}
