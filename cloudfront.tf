# CloudFront Distribution with Origin Failover

resource "aws_cloudfront_distribution" "main" {
  provider = aws.primary
  enabled  = true
  comment  = "${local.app_name} - Multi-region SSR"

  # Aliases for custom domain - support both prod domain AND custom domain
  aliases = compact([
    var.environment == "prod" ? local.domains.primary : "",  # Route53 domain (prod only)
    var.custom_domain != "" ? var.custom_domain : ""         # External custom domain (if set)
  ])

  # Origin Group for failover
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

  # Primary Origin (us-east-1 Lambda Function URL)
  origin {
    domain_name = regex("https://([^/]+)/?", aws_lambda_function_url.primary.function_url)[0]
    origin_id   = "primary-lambda"

    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.primary_region
    }
  }

  # DR Origin (us-west-2 Lambda Function URL)
  origin {
    domain_name = var.enable_dr ? regex("https://([^/]+)/?", aws_lambda_function_url.dr[0].function_url)[0] : ""
    origin_id   = "dr-lambda"

    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.dr_region
    }
  }

  # Static Assets Origin (S3)
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id   = "static-assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  # Default cache behavior (SSR - dynamic content)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-group-primary-dr"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  # Static assets cache behavior
  ordered_cache_behavior {
    path_pattern     = "/_nuxt/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "static-assets"

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

  # Favicon cache behavior
  ordered_cache_behavior {
    path_pattern     = "/favicon.ico"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "static-assets"

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

  # SSL Certificate
  # Priority: custom_domain cert > prod cert > CloudFront default
  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain == "" && var.environment != "prod"
    acm_certificate_arn = var.custom_domain != "" ? aws_acm_certificate.custom_domain[0].arn : (
      var.environment == "prod" ? aws_acm_certificate.main[0].arn : null
    )
    ssl_support_method       = var.custom_domain != "" || var.environment == "prod" ? "sni-only" : null
    minimum_protocol_version = var.custom_domain != "" || var.environment == "prod" ? "TLSv1.2_2021" : null
  }

  # Geo restrictions (none for PoC)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Logging (optional)
  # logging_config {
  #   include_cookies = false
  #   bucket         = aws_s3_bucket.logs.bucket_domain_name
  #   prefix         = "cloudfront/"
  # }

  tags = local.common_tags
}

# Origin Access Identity for S3
resource "aws_cloudfront_origin_access_identity" "main" {
  provider = aws.primary
  comment  = "OAI for ${local.app_name} static assets"
}
