output "oai_cloudfront_access_identity_path" {
  value = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
}

output "oai_s3_canonical_user_id" {
  value = aws_cloudfront_origin_access_identity.main.s3_canonical_user_id
}

output "lambda_oac_id" {
  value = aws_cloudfront_origin_access_control.lambda.id
}

output "lambda_signed_origin_request_policy_id" {
  value = aws_cloudfront_origin_request_policy.lambda_signed.id
}

output "ssr_swr_cache_policy_id" {
  value = aws_cloudfront_cache_policy.ssr_swr.id
}
