# Serverless SSR Platform - Outputs
# These outputs provide everything the application needs for deployment

# Lambda Configuration
# ------------------------------------------------------------------------------

output "lambda_function_name_primary" {
  description = "Primary region Lambda function name"
  value       = module.lambda_primary.function_name
}

output "lambda_function_name_dr" {
  description = "DR region Lambda function name"
  value       = var.enable_dr ? module.lambda_dr[0].function_name : null
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
  value       = module.storage.static_assets_id
}

output "s3_bucket_deployments_primary" {
  description = "S3 bucket for Lambda deployments (primary)"
  value       = module.storage.lambda_deployments_primary_id
}

output "s3_bucket_deployments_dr" {
  description = "S3 bucket for Lambda deployments (DR)"
  value       = var.enable_dr ? module.storage.lambda_deployments_dr_id : null
}

# CloudFront
# ------------------------------------------------------------------------------

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = module.cloudfront.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.cloudfront.domain_name
}

# Application
# ------------------------------------------------------------------------------

output "application_url" {
  description = "Application URL"
  value       = local.enable_custom_domain ? "https://${local.full_domain}" : "https://${module.cloudfront.domain_name}"
}

output "custom_domain_enabled" {
  description = "Whether custom domain is configured"
  value       = local.enable_custom_domain
}

output "route53_managed" {
  description = "Whether domain is managed by Route53"
  value       = local.enable_route53
}

# DynamoDB
# ------------------------------------------------------------------------------

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = var.enable_dynamo ? module.dynamodb[0].table_name_primary : null
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = var.enable_dynamo ? module.dynamodb[0].table_arn_primary : null
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
        function_name = module.lambda_primary.function_name
        function_url  = aws_lambda_function_url.primary.function_url
        s3_bucket     = module.storage.lambda_deployments_primary_id
        s3_key        = "lambda/function.zip"
      }
      dr = var.enable_dr ? {
        function_name = module.lambda_dr[0].function_name
        function_url  = aws_lambda_function_url.dr[0].function_url
        s3_bucket     = module.storage.lambda_deployments_dr_id
        s3_key        = "lambda/function.zip"
      } : null
    }
    static_assets = {
      s3_bucket = module.storage.static_assets_id
    }
    cloudfront = {
      distribution_id = module.cloudfront.id
      domain_name     = module.cloudfront.domain_name
    }
    dynamodb = var.enable_dynamo ? {
      table_name = module.dynamodb[0].table_name_primary
    } : null
  }
}

# Origin Secret
# ------------------------------------------------------------------------------

# Note: Removed in v2.4.1 - AWS_IAM authentication replaces X-Origin-Secret header validation
# output "origin_secret" {
#   description = "Secret value CloudFront injects as X-Origin-Secret header. App verifies this to block direct Lambda URL access."
#   value       = random_uuid.origin_secret.result
#   sensitive   = true
# }

# DNS Records for Manual Configuration
# ------------------------------------------------------------------------------
# If domain is NOT managed by Route53, these records must be added manually

output "dns_validation_records" {
  description = "DNS records for ACM certificate validation (add these to your DNS provider if route53_managed = false)"
  value       = module.dns.dns_validation_records
}

output "dns_cloudfront_record" {
  description = "DNS record to point domain to CloudFront (add this to your DNS provider if route53_managed = false)"
  value       = module.dns.dns_cloudfront_record
}
