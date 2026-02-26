module "storage" {
  source  = "pomo-studio/ssr-storage/aws"
  version = "= 0.1.0"

  providers = {
    aws    = aws.primary
    aws.dr = aws.dr
  }

  app_name                         = local.app_name
  account_id                       = data.aws_caller_identity.current.account_id
  primary_region                   = var.primary_region
  dr_region                        = var.dr_region
  enable_dr                        = var.enable_dr
  common_tags                      = local.common_tags
  cloudfront_oai_canonical_user_id = module.cloudfront_support.oai_s3_canonical_user_id
}
