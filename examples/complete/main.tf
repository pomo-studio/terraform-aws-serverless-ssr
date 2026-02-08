# Complete Example - Serverless SSR Module
# Full production setup with custom domain, DR, and CI/CD

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

module "ssr" {
  source = "../.." # References the module root

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name = var.project_name
  environment  = var.environment

  # Custom domain configuration (Route53 managed)
  domain_name     = var.domain_name
  subdomain       = var.subdomain
  route53_managed = var.route53_managed

  # Enable all features
  enable_dr         = true
  create_ci_cd_user = true

  # Custom Lambda configuration
  lambda_memory_size = 1024
  lambda_timeout     = 30

  # Additional tags
  tags = {
    ManagedBy = "Terraform"
    Example   = "Complete"
  }
}
