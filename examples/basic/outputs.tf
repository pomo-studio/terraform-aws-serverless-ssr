output "application_url" {
  description = "Application URL"
  value       = module.ssr.application_url
}

output "app_config" {
  description = "App configuration"
  value       = module.ssr.app_config
  sensitive   = true
}
