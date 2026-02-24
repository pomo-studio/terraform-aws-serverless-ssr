terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cloudfront_origin_access_identity" "main" {
  comment = "OAI for ${var.app_name} static assets"
}

resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "${var.app_name}-lambda-oac"
  description                       = "OAC for ${var.app_name} Lambda Function URLs"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_request_policy" "lambda_signed" {
  name = "${var.app_name}-lambda-signed"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "accept",
        "accept-language",
        "cache-control",
        "content-type",
        "origin",
        "referer",
        "user-agent"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_cache_policy" "ssr_swr" {
  name        = "${var.app_name}-ssr-swr"
  comment     = "SSR with Stale-While-Revalidate support"
  default_ttl = 60
  max_ttl     = 86400

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
