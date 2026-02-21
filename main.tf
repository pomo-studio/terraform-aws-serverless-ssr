# Serverless SSR Platform - Main Configuration
# Multi-region serverless SSR with CloudFront failover
#
# NOTE: This module requires AWS providers with aliases "primary" and "dr"
# to be passed from the calling module.
#
# Example:
#   module "ssr_platform" {
#     source = "./modules/ssr-platform"
#     providers = {
#       aws.primary = aws.primary
#       aws.dr      = aws.dr
#     }
#     ...
#   }


# Local Values
# ------------------------------------------------------------------------------

locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)

  # Normalize project name for resource naming
  app_name = var.project_name

  # Custom domain configuration
  enable_custom_domain = var.domain_name != null
  enable_route53       = local.enable_custom_domain && var.route53_managed
  full_domain = local.enable_custom_domain ? (
    var.subdomain != null && var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  ) : null
}

# Data Sources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {
  provider = aws.primary
}
