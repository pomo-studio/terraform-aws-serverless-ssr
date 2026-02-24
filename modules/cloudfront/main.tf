terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled = true
  comment = "${var.app_name} - Multi-region SSR"
  aliases = var.enable_custom_domain ? [var.full_domain] : []

  origin_group {
    origin_id = "origin-group-primary-dr"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "primary-lambda"
    }

    member {
      origin_id = "dr-lambda"
    }
  }

  origin_group {
    origin_id = "origin-group-static-assets"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "static-assets-primary"
    }

    member {
      origin_id = "static-assets-dr"
    }
  }

  origin {
    domain_name              = regex("https://([^/]+)/?", var.primary_lambda_function_url)[0]
    origin_id                = "primary-lambda"
    origin_access_control_id = var.lambda_oac_id

    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = var.enable_dr ? regex("https://([^/]+)/?", var.dr_lambda_function_url)[0] : ""
    origin_id                = "dr-lambda"
    origin_access_control_id = var.lambda_oac_id

    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = var.static_assets_regional_domain_name
    origin_id   = "static-assets-primary"

    s3_origin_config {
      origin_access_identity = var.oai_cloudfront_access_identity_path
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.primary_region
    }
  }

  origin {
    domain_name = var.enable_dr ? var.static_assets_dr_regional_domain_name : ""
    origin_id   = "static-assets-dr"

    s3_origin_config {
      origin_access_identity = var.oai_cloudfront_access_identity_path
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.dr_region
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-lambda"

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = var.lambda_signed_origin_request_policy_id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-group-primary-dr"

    cache_policy_id          = var.ssr_swr_cache_policy_id
    origin_request_policy_id = var.lambda_signed_origin_request_policy_id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/_nuxt/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-group-static-assets"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 604800
    max_ttl                = 31536000
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/favicon.ico"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-group-static-assets"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 86400
    default_ttl            = 604800
    max_ttl                = 31536000
    compress               = true
  }

  viewer_certificate {
    cloudfront_default_certificate = !var.enable_custom_domain
    acm_certificate_arn            = var.enable_custom_domain ? var.certificate_arn : null
    ssl_support_method             = var.enable_custom_domain ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domain ? "TLSv1.2_2021" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = var.common_tags
}
