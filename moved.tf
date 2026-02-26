moved {
  from = aws_lambda_function.primary
  to   = module.lambda_primary.aws_lambda_function.this
}

moved {
  from = aws_lambda_function.dr[0]
  to   = module.lambda_dr[0].aws_lambda_function.this
}

moved {
  from = aws_cloudfront_origin_access_identity.main
  to   = module.cloudfront_support.aws_cloudfront_origin_access_identity.main
}

moved {
  from = aws_cloudfront_origin_access_control.lambda
  to   = module.cloudfront_support.aws_cloudfront_origin_access_control.lambda
}

moved {
  from = aws_cloudfront_origin_request_policy.lambda_signed
  to   = module.cloudfront_support.aws_cloudfront_origin_request_policy.lambda_signed
}

moved {
  from = aws_cloudfront_cache_policy.ssr_swr
  to   = module.cloudfront_support.aws_cloudfront_cache_policy.ssr_swr
}

moved {
  from = aws_cloudfront_distribution.main
  to   = module.cloudfront.aws_cloudfront_distribution.main
}

moved {
  from = aws_s3_bucket.lambda_deployments_primary
  to   = module.storage.aws_s3_bucket.lambda_deployments_primary
}

moved {
  from = aws_s3_bucket_versioning.lambda_deployments_primary
  to   = module.storage.aws_s3_bucket_versioning.lambda_deployments_primary
}

moved {
  from = aws_s3_bucket.lambda_deployments_dr[0]
  to   = module.storage.aws_s3_bucket.lambda_deployments_dr[0]
}

moved {
  from = aws_s3_bucket_versioning.lambda_deployments_dr[0]
  to   = module.storage.aws_s3_bucket_versioning.lambda_deployments_dr[0]
}

moved {
  from = aws_s3_bucket.static_assets
  to   = module.storage.aws_s3_bucket.static_assets
}

moved {
  from = aws_s3_bucket_public_access_block.static_assets
  to   = module.storage.aws_s3_bucket_public_access_block.static_assets
}

moved {
  from = aws_s3_bucket_versioning.static_assets
  to   = module.storage.aws_s3_bucket_versioning.static_assets
}

moved {
  from = aws_s3_bucket_policy.static_assets
  to   = module.storage.aws_s3_bucket_policy.static_assets
}

moved {
  from = aws_s3_bucket_replication_configuration.static_assets[0]
  to   = module.storage.aws_s3_bucket_replication_configuration.static_assets[0]
}

moved {
  from = aws_s3_bucket.static_assets_dr[0]
  to   = module.storage.aws_s3_bucket.static_assets_dr[0]
}

moved {
  from = aws_s3_bucket_versioning.static_assets_dr[0]
  to   = module.storage.aws_s3_bucket_versioning.static_assets_dr[0]
}

moved {
  from = aws_s3_bucket_public_access_block.static_assets_dr[0]
  to   = module.storage.aws_s3_bucket_public_access_block.static_assets_dr[0]
}

moved {
  from = aws_s3_bucket_policy.static_assets_dr[0]
  to   = module.storage.aws_s3_bucket_policy.static_assets_dr[0]
}

moved {
  from = aws_iam_role.replication
  to   = module.storage.aws_iam_role.replication
}

moved {
  from = aws_iam_policy.replication
  to   = module.storage.aws_iam_policy.replication
}

moved {
  from = aws_iam_role_policy_attachment.replication
  to   = module.storage.aws_iam_role_policy_attachment.replication
}

moved {
  from = aws_route53_record.main[0]
  to   = module.dns.aws_route53_record.main[0]
}

moved {
  from = aws_route53_record.cert_validation
  to   = module.dns.aws_route53_record.cert_validation
}

moved {
  from = aws_acm_certificate.main[0]
  to   = module.dns.aws_acm_certificate.main[0]
}

moved {
  from = aws_acm_certificate_validation.main[0]
  to   = module.dns.aws_acm_certificate_validation.main[0]
}

moved {
  from = aws_dynamodb_table.visits_primary[0]
  to   = module.dynamodb[0].aws_dynamodb_table.primary
}

moved {
  from = aws_dynamodb_table_replica.visits_dr[0]
  to   = module.dynamodb[0].aws_dynamodb_table_replica.dr[0]
}
