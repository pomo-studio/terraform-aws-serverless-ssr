module "cloudfront_support" {
  source = "git::https://github.com/pomo-studio/terraform-aws-ssr-cloudfront-support.git?ref=v0.1.0"

  providers = {
    aws = aws.primary
  }

  app_name = local.app_name
}

module "cloudfront" {
  source = "git::https://github.com/pomo-studio/terraform-aws-ssr-cloudfront.git?ref=v0.1.0"

  providers = {
    aws = aws.primary
  }

  app_name                               = local.app_name
  enable_custom_domain                   = local.enable_custom_domain
  full_domain                            = local.full_domain
  enable_dr                              = var.enable_dr
  primary_lambda_function_url            = aws_lambda_function_url.primary.function_url
  dr_lambda_function_url                 = var.enable_dr ? aws_lambda_function_url.dr[0].function_url : null
  lambda_oac_id                          = module.cloudfront_support.lambda_oac_id
  static_assets_regional_domain_name     = module.storage.static_assets_regional_domain_name
  static_assets_dr_regional_domain_name  = module.storage.static_assets_dr_regional_domain_name
  oai_cloudfront_access_identity_path    = module.cloudfront_support.oai_cloudfront_access_identity_path
  primary_region                         = var.primary_region
  dr_region                              = var.dr_region
  lambda_signed_origin_request_policy_id = module.cloudfront_support.lambda_signed_origin_request_policy_id
  ssr_swr_cache_policy_id                = module.cloudfront_support.ssr_swr_cache_policy_id
  certificate_arn                        = module.dns.certificate_arn
  common_tags                            = local.common_tags
}
