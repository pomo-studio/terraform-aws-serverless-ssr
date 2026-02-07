# Complete Example - Serverless SSR Module

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
  source = "../.."  # References the module root

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name = var.project_name
  domain_name  = var.domain_name
  subdomain    = var.subdomain
  environment  = var.environment

  # Enable all features
  enable_dr         = true
  create_ci_cd_user = true
  custom_domain     = var.custom_domain

  lambda_memory_size = 1024
  lambda_timeout     = 30
}
