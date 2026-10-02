module "dns" {
  source  = "pomo-studio/ssr-dns/aws"
  version = "0.4.0"

  providers = {
    aws = aws.primary
  }

  enable_custom_domain      = local.enable_custom_domain
  enable_route53            = local.enable_route53
  domain_name               = var.domain_name
  full_domain               = local.full_domain
  additional_domain_names   = local.enable_custom_domain ? var.additional_domain_names : []
  certificate_arn           = var.certificate_arn
  app_name                  = local.app_name
  common_tags               = local.common_tags
  cloudfront_domain_name    = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
}
