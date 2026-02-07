output "application_url" {
  description = "Application URL"
  value       = module.ssr.application_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.ssr.cloudfront_distribution_id
}

output "lambda_function_name_primary" {
  description = "Primary Lambda function name"
  value       = module.ssr.lambda_function_name_primary
}

output "cicd_access_key_id" {
  description = "CI/CD AWS access key ID"
  value       = module.ssr.cicd_aws_access_key_id
}

output "app_config" {
  description = "Complete app configuration"
  value       = module.ssr.app_config
  sensitive   = true
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ✅ Infrastructure deployed successfully!
    
    1. Save app configuration:
       terraform output -json app_config > config/infra-outputs.json
    
    2. Deploy your application:
       cd ~/my-app && ./scripts/deploy.sh
    
    3. Verify:
       curl ${module.ssr.application_url}/api/health
    
  EOT
}
