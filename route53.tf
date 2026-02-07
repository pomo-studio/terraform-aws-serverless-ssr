# Route53 DNS and Health Checks
# Note: For dev environment, you can skip Route53 and use CloudFront domain directly
# For prod, ensure the Route53 zone exists or create one

# Route53 Zone (data source - only if zone exists)
# Uncomment this when you have a Route53 zone for your domain
data "aws_route53_zone" "main" {
  count        = var.environment == "prod" ? 1 : 0
  provider     = aws.primary
  name         = var.domain_name
  private_zone = false
}

# Health Check for Primary Region (only in prod)
resource "aws_route53_health_check" "primary" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.primary

  fqdn              = replace(aws_lambda_function_url.primary.function_url, "https://", "")
  port              = 443
  type              = "HTTPS"
  resource_path     = "/api/health"
  failure_threshold = 3
  request_interval  = 30

  regions = ["us-east-1", "us-west-2", "eu-west-1"]

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-primary-health"
  })
}

# Health Check for DR Region (only in prod, only if DR enabled)
resource "aws_route53_health_check" "dr" {
  count    = var.environment == "prod" && var.enable_dr ? 1 : 0
  provider = aws.primary

  fqdn              = replace(aws_lambda_function_url.dr[0].function_url, "https://", "")
  port              = 443
  type              = "HTTPS"
  resource_path     = "/api/health"
  failure_threshold = 3
  request_interval  = 30

  regions = ["us-east-1", "us-west-2", "eu-west-1"]

  tags = merge(local.common_tags, {
    Name = "${local.app_name}-dr-health"
  })
}

# DNS Record for Primary (Failover) - only if zone exists
resource "aws_route53_record" "primary" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.primary
  zone_id  = data.aws_route53_zone.main[0].zone_id
  name     = local.domains.primary
  type     = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary[0].id
  set_identifier  = "primary"
}

# DNS Record for DR (Failover) - only if zone exists
resource "aws_route53_record" "dr" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.primary
  zone_id  = data.aws_route53_zone.main[0].zone_id
  name     = local.domains.primary
  type     = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.dr[0].id
  set_identifier  = "dr"
}

# ACM Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "main" {
  provider          = aws.primary
  count             = var.environment == "prod" ? 1 : 0
  domain_name       = local.domains.primary
  validation_method = "DNS"

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate Validation - only in prod with Route53 zone
resource "aws_route53_record" "cert_validation" {
  provider = aws.primary
  for_each = var.environment == "prod" ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main[0].zone_id
}

resource "aws_acm_certificate_validation" "main" {
  provider                = aws.primary
  count                   = var.environment == "prod" ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ACM Certificate for Custom Domain (DNS validation via external provider like Squarespace)
# Note: This certificate requires manual DNS validation - see outputs for validation records
resource "aws_acm_certificate" "custom_domain" {
  provider          = aws.primary  # Must be us-east-1 for CloudFront
  count             = var.custom_domain != "" ? 1 : 0

  domain_name       = var.custom_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name   = "${local.app_name}-custom-domain"
    Domain = var.custom_domain
  })
}
