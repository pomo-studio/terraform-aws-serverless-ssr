variable "enable_custom_domain" {
  description = "Whether custom domain resources are enabled"
  type        = bool
}

variable "enable_route53" {
  description = "Whether Route53-managed DNS resources are enabled"
  type        = bool
}

variable "domain_name" {
  description = "Base domain name"
  type        = string
  default     = null
}

variable "full_domain" {
  description = "Computed full domain for certificate and records"
  type        = string
  default     = null
}

variable "app_name" {
  description = "Application name for resource naming"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "cloudfront_domain_name" {
  description = "CloudFront domain name for alias record"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone id for alias record"
  type        = string
}
