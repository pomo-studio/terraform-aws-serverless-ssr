# CloudFront Distribution with Origin Failover

resource "aws_cloudfront_distribution" "main" {
  provider = aws.primary
  enabled  = true
  comment  = "${local.app_name} - Multi-region SSR"

  # Aliases for custom domain (only if domain_name is set)
  aliases = local.enable_custom_domain ? [local.full_domain] : []

  # Origin Group for Lambda failover
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

  # Origin Group for S3 Static Assets failover
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

  # Primary Origin (us-east-1 Lambda Function URL)
  origin {
    domain_name              = regex("https://([^/]+)/?", aws_lambda_function_url.primary.function_url)[0]
    origin_id                = "primary-lambda"
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

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
    domain_name              = var.enable_dr ? regex("https://([^/]+)/?", aws_lambda_function_url.dr[0].function_url)[0] : ""
    origin_id                = "dr-lambda"
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

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

  # Static Assets Origin - Primary (S3)
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id   = "static-assets-primary"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.primary_region
    }
  }

  # Static Assets Origin - DR (S3)
  origin {
    domain_name = var.enable_dr ? aws_s3_bucket.static_assets_dr[0].bucket_regional_domain_name : ""
    origin_id   = "static-assets-dr"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }

    custom_header {
      name  = "X-Origin-Region"
      value = var.dr_region
    }
  }

  # Default cache behavior (SSR - dynamic content)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-group-primary-dr"

    # Cache policies are required for CloudFront OAC + Lambda Function URL.
    # Legacy forwarded_values prevents OAC from signing requests (AccessDeniedException).
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # Managed-AllViewerExceptHostHeader

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Static assets cache behavior
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

  # Favicon cache behavior
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

  # SSL Certificate
  # Use ACM certificate if custom domain is configured, otherwise use CloudFront default
  viewer_certificate {
    cloudfront_default_certificate = !local.enable_custom_domain
    acm_certificate_arn            = local.enable_custom_domain ? aws_acm_certificate.main[0].arn : null
    ssl_support_method             = local.enable_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.enable_custom_domain ? "TLSv1.2_2021" : null
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

# Origin Access Control for Lambda Function URLs
# Signs CloudFront → Lambda requests with SigV4 so Lambda can require AWS_IAM auth.
# Direct access to Lambda Function URLs returns 403 Forbidden.
resource "aws_cloudfront_origin_access_control" "lambda" {
  provider = aws.primary

  name                              = "${local.app_name}-lambda-oac"
  description                       = "OAC for ${local.app_name} Lambda Function URLs"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
