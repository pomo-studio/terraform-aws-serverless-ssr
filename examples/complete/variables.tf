variable "project_name" {
  description = "Project name"
  type        = string
  default     = "my-app-prod"
}

variable "domain_name" {
  description = "Base domain name (e.g., example.com). Set to null to use CloudFront domain."
  type        = string
  default     = "example.com"
}

variable "subdomain" {
  description = "Subdomain for the application (e.g., app, www)"
  type        = string
  default     = "app"
}

variable "route53_managed" {
  description = "Whether domain is hosted in Route53 (enables automatic DNS management)"
  type        = bool
  default     = false  # Set to true when you have the domain in Route53
}

variable "environment" {
  description = "Environment name"
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
