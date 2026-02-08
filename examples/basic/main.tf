# Basic Example - Serverless SSR Module
# Minimal setup: No custom domain, no DR, no CI/CD
# Perfect for development and testing

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

  # No domain configuration - uses CloudFront URL
  # domain_name and subdomain are omitted (defaults to null)

  # Disable DR and CI/CD for minimal setup
  enable_dr         = false
  create_ci_cd_user = false
}
