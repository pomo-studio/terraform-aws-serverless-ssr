# Serverless SSR Platform - Module Variables

# Required Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for all resources. Must be unique, lowercase alphanumeric with hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "Project name must be 3-20 characters, lowercase alphanumeric with hyphens only."
  }
}

# Optional Domain Configuration
# ------------------------------------------------------------------------------
# Leave domain_name as null to use CloudFront domain only (no Route53 required)
# Set domain_name to enable custom domain with ACM certificate
# Set route53_managed = true if domain is hosted in Route53 for automatic DNS management

variable "domain_name" {
  description = "Base domain name (e.g., example.com). Leave null to use CloudFront domain only."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || can(regex("^[a-z0-9][a-z0-9-.]*\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com) or null."
  }
}

variable "subdomain" {
  description = "Subdomain for the application (e.g., app, www). Leave null or empty for root domain."
  type        = string
  default     = null
}

variable "route53_managed" {
  description = "Whether domain is hosted in Route53 (enables automatic DNS management and validation). Only applies if domain_name is set."
  type        = bool
  default     = false
}

# Optional Variables
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "DR AWS region"
  type        = string
  default     = "us-west-2"
}

variable "enable_dr" {
  description = "Enable DR region deployment"
  type        = bool
  default     = true
}

variable "enable_dynamo" {
  description = "Deploy DynamoDB global table. Set false if your app has no persistence needs or uses an external database."
  type        = bool
  default     = true
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "create_ci_cd_user" {
  description = "Create IAM user for CI/CD deployments. Prefer OIDC (set false) over static credentials."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
