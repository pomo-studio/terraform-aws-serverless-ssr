variable "app_name" {
  description = "Normalized app name for resource naming"
  type        = string
}

variable "account_id" {
  description = "AWS account id"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "DR AWS region"
  type        = string
}

variable "enable_dr" {
  description = "Enable DR resources"
  type        = bool
}

variable "common_tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

variable "cloudfront_oai_canonical_user_id" {
  description = "CloudFront OAI canonical user id for bucket policies"
  type        = string
}
