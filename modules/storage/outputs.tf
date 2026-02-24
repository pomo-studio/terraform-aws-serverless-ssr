output "lambda_deployments_primary_id" {
  value = aws_s3_bucket.lambda_deployments_primary.id
}

output "lambda_deployments_primary_arn" {
  value = aws_s3_bucket.lambda_deployments_primary.arn
}

output "lambda_deployments_dr_id" {
  value = var.enable_dr ? aws_s3_bucket.lambda_deployments_dr[0].id : null
}

output "lambda_deployments_dr_arn" {
  value = var.enable_dr ? aws_s3_bucket.lambda_deployments_dr[0].arn : null
}

output "static_assets_id" {
  value = aws_s3_bucket.static_assets.id
}

output "static_assets_arn" {
  value = aws_s3_bucket.static_assets.arn
}

output "static_assets_regional_domain_name" {
  value = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "static_assets_dr_id" {
  value = var.enable_dr ? aws_s3_bucket.static_assets_dr[0].id : null
}

output "static_assets_dr_arn" {
  value = var.enable_dr ? aws_s3_bucket.static_assets_dr[0].arn : null
}

output "static_assets_dr_regional_domain_name" {
  value = var.enable_dr ? aws_s3_bucket.static_assets_dr[0].bucket_regional_domain_name : null
}
