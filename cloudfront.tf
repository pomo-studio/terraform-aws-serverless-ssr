# Custom origin request policy for Lambda Function URLs
# Excludes Content-Length and Transfer-Encoding headers which CloudFront modifies
# after signing, causing signature validation failures with AWS_IAM auth
resource "aws_cloudfront_origin_request_policy" "lambda_no_body_headers" {
  provider = aws.primary
  name     = "${local.app_name}-lambda-no-body-headers"
  comment  = "For Lambda Function URLs with AWS_IAM auth - excludes problematic body headers"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
    # CloudFront automatically excludes problematic body headers (Content-Length, Transfer-Encoding)
    # when forwarding to origins, which is needed for AWS_IAM authentication
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

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

  # API routes cache behavior — direct to primary Lambda (origin groups prohibit POST/PUT/PATCH/DELETE)
  # CloudFront cannot retry non-idempotent methods on a failover origin, so /api/* bypasses the
  # origin group and targets the primary Lambda directly. Caching is disabled for all API routes.
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "primary-lambda"

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = aws_cloudfront_origin_request_policy.lambda_no_body_headers.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Default cache behavior (SSR - dynamic content with Stale-While-Revalidate)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-group-primary-dr"

    # Custom cache policy that honors origin Cache-Control headers
    # Enables Stale-While-Revalidate pattern for instant page loads
    cache_policy_id          = aws_cloudfront_cache_policy.ssr_swr.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.lambda_no_body_headers.id

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


# Cache Policy for SSR with Stale-While-Revalidate
# -----------------------------------------------------------------------------
# This policy enables the SWR pattern:
# - CloudFront serves cached content immediately (fast!)
# - Background fetch updates the cache (fresh content)
# - Lambda controls caching via Cache-Control headers
#
# Cache-Control header examples from Lambda:
#   - public, max-age=60, stale-while-revalidate=300
#     → Cache 60s, serve stale for 300s while revalidating
#   - no-store
#     → Never cache (for private pages)
#   - public, max-age=0, stale-while-revalidate=60
#     → Always serve from cache, refresh in background (max 60s stale)

resource "aws_cloudfront_cache_policy" "ssr_swr" {
  provider = aws.primary

  name        = "${local.app_name}-ssr-swr"
  comment     = "SSR with Stale-While-Revalidate support"
  default_ttl = 60    # Fallback if no Cache-Control header
  max_ttl     = 86400 # 24 hours max (overridden by s-maxage if present)

  # Honor origin Cache-Control headers - this is key for SWR
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}
