module "dns" {
  source = "git::https://github.com/pomo-studio/terraform-aws-ssr-dns.git?ref=v0.1.0"

  providers = {
    aws = aws.primary
  }

  enable_custom_domain      = local.enable_custom_domain
  enable_route53            = local.enable_route53
  domain_name               = var.domain_name
  full_domain               = local.full_domain
  app_name                  = local.app_name
  common_tags               = local.common_tags
  cloudfront_domain_name    = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
}
