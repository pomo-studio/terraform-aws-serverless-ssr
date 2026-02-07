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

variable "domain_name" {
  description = "Base domain name (e.g., example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application (e.g., app, www)"
  type        = string
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

variable "custom_domain" {
  description = "Custom domain for CloudFront (e.g., app.example.com). Leave empty to use CloudFront domain only."
  type        = string
  default     = ""
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
  description = "Create IAM user for CI/CD deployments"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
