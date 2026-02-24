variable "app_name" {
  type = string
}

variable "enable_custom_domain" {
  type = bool
}

variable "full_domain" {
  type    = string
  default = null
}

variable "enable_dr" {
  type = bool
}

variable "primary_lambda_function_url" {
  type = string
}

variable "dr_lambda_function_url" {
  type    = string
  default = null
}

variable "lambda_oac_id" {
  type = string
}

variable "static_assets_regional_domain_name" {
  type = string
}

variable "static_assets_dr_regional_domain_name" {
  type    = string
  default = null
}

variable "oai_cloudfront_access_identity_path" {
  type = string
}

variable "primary_region" {
  type = string
}

variable "dr_region" {
  type = string
}

variable "lambda_signed_origin_request_policy_id" {
  type = string
}

variable "ssr_swr_cache_policy_id" {
  type = string
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
