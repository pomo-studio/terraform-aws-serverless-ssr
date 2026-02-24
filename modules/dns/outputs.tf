output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.enable_custom_domain ? aws_acm_certificate.main[0].arn : null
}

output "dns_validation_records" {
  description = "DNS records for ACM certificate validation"
  value = var.enable_custom_domain && !var.enable_route53 ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

output "dns_cloudfront_record" {
  description = "DNS record values for manual CloudFront configuration"
  value = var.enable_custom_domain && !var.enable_route53 ? {
    name  = var.full_domain
    type  = "A (Alias) or CNAME"
    value = var.cloudfront_domain_name
    note  = "Use A record (alias) if supported, otherwise CNAME"
  } : null
}
