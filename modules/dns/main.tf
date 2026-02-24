terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_route53_zone" "main" {
  count        = var.enable_route53 ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "main" {
  count   = var.enable_route53 ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.full_domain
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "main" {
  count             = var.enable_custom_domain ? 1 : 0
  domain_name       = var.full_domain
  validation_method = "DNS"

  tags = merge(var.common_tags, {
    Name = "${var.app_name}-${var.full_domain}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_route53 ? {
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
  count                   = var.enable_route53 ? 1 : 0
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
