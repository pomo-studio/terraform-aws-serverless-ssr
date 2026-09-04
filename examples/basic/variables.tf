variable "project_name" {
  description = "Project name"
  type        = string
  default     = "my-app-dev"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
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

# Optional: Custom domain variables (not used in basic example but declared for compatibility)
# tflint-ignore: terraform_unused_declarations
variable "domain_name" {
  description = "Base domain name (e.g., example.com). Set to null to use CloudFront domain."
  type        = string
  default     = null
}

# tflint-ignore: terraform_unused_declarations
variable "subdomain" {
  description = "Subdomain for the application (e.g., app, www)"
  type        = string
  default     = null
}

# tflint-ignore: terraform_unused_declarations
variable "route53_managed" {
  description = "Whether domain is hosted in Route53"
  type        = bool
  default     = false
}
