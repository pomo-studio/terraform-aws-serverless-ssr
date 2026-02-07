# Serverless SSR Platform - Outputs
# These outputs provide everything the application needs for deployment

# Lambda Configuration
# ------------------------------------------------------------------------------

output "lambda_function_name_primary" {
  description = "Primary region Lambda function name"
  value       = aws_lambda_function.primary.function_name
}

output "lambda_function_name_dr" {
  description = "DR region Lambda function name"
  value       = var.enable_dr ? aws_lambda_function.dr[0].function_name : null
}

output "lambda_function_url_primary" {
  description = "Primary Lambda function URL"
  value       = aws_lambda_function_url.primary.function_url
}

output "lambda_function_url_dr" {
  description = "DR Lambda function URL"
  value       = var.enable_dr ? aws_lambda_function_url.dr[0].function_url : null
}

# S3 Buckets
# ------------------------------------------------------------------------------

output "s3_bucket_static" {
  description = "S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.id
}

output "s3_bucket_deployments_primary" {
  description = "S3 bucket for Lambda deployments (primary)"
  value       = aws_s3_bucket.lambda_deployments_primary.id
}

output "s3_bucket_deployments_dr" {
  description = "S3 bucket for Lambda deployments (DR)"
  value       = var.enable_dr ? aws_s3_bucket.lambda_deployments_dr[0].id : null
}

# CloudFront
# ------------------------------------------------------------------------------

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

# Application
# ------------------------------------------------------------------------------

output "application_url" {
  description = "Application URL"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

# DynamoDB
# ------------------------------------------------------------------------------

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.visits_primary.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.visits_primary.arn
}

# CI/CD Credentials (sensitive)
# ------------------------------------------------------------------------------

output "cicd_aws_access_key_id" {
  description = "AWS access key for CI/CD deployments"
  value       = var.create_ci_cd_user && length(aws_iam_access_key.cicd) > 0 ? aws_iam_access_key.cicd[0].id : null
  sensitive   = false
}

output "cicd_aws_secret_access_key" {
  description = "AWS secret key for CI/CD deployments"
  value       = var.create_ci_cd_user && length(aws_iam_access_key.cicd) > 0 ? aws_iam_access_key.cicd[0].secret : null
  sensitive   = true
}

# Complete App Configuration
# This output bundles everything the app needs
# ------------------------------------------------------------------------------

output "app_config" {
  description = "Complete configuration for application deployment"
  value = {
    project_name   = var.project_name
    primary_region = var.primary_region
    dr_region      = var.dr_region
    lambda = {
      primary = {
        function_name = aws_lambda_function.primary.function_name
        function_url  = aws_lambda_function_url.primary.function_url
        s3_bucket     = aws_s3_bucket.lambda_deployments_primary.id
        s3_key        = "lambda/function.zip"
      }
      dr = var.enable_dr ? {
        function_name = aws_lambda_function.dr[0].function_name
        function_url  = aws_lambda_function_url.dr[0].function_url
        s3_bucket     = aws_s3_bucket.lambda_deployments_dr[0].id
        s3_key        = "lambda/function.zip"
      } : null
    }
    static_assets = {
      s3_bucket = aws_s3_bucket.static_assets.id
    }
    cloudfront = {
      distribution_id   = aws_cloudfront_distribution.main.id
      domain_name       = aws_cloudfront_distribution.main.domain_name
    }
    dynamodb = {
      table_name = aws_dynamodb_table.visits_primary.name
    }
  }
}

# Custom Domain (if enabled)
# ------------------------------------------------------------------------------

output "custom_domain_validation_records" {
  description = "DNS records for ACM certificate validation"
  value = var.custom_domain != "" ? {
    for dvo in aws_acm_certificate.custom_domain[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

output "custom_domain_cname" {
  description = "CNAME record to point custom domain to CloudFront"
  value = var.custom_domain != "" ? {
    name  = var.custom_domain
    type  = "CNAME"
    value = aws_cloudfront_distribution.main.domain_name
  } : null
}
