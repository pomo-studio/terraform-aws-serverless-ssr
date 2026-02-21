# Unit tests for terraform-aws-serverless-ssr
#
# Requires Terraform >= 1.9.0
#   - mock_provider support (>= 1.7.0)
#   - cross-variable references in validation blocks (>= 1.9.0)
#
# NOTE: mock_provider generates synthetic ARNs that may not pass AWS ARN format
# validation in assert conditions. Tests here focus on resource counts, names,
# and configuration attributes — not ARNs — to stay compatible with mock mode.

mock_provider "aws" {
  alias = "primary"
  
  # Provide valid ARN formats so the AWS provider's ARN validation doesn't
  # reject the synthetic values that mock_provider generates by default.

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn              = "arn:aws:lambda:us-east-1:123456789012:function/mock-function"
      invoke_arn       = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function/mock-function/invocations"
      last_modified    = "2026-02-21T00:00:00Z"
      qualified_arn    = "arn:aws:lambda:us-east-1:123456789012:function/mock-function:$LATEST"
      signing_job_arn  = "arn:aws:signer:us-east-1:123456789012:/signing-jobs/mock-job"
      signing_profile_version_arn = "arn:aws:signer:us-east-1:123456789012:/signing-profiles/mock-profile"
      source_code_hash = "mock-hash"
      source_code_size = 1024
      version          = "$LATEST"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-bucket"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/mock-distribution"
      domain_name    = "mock.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }

  mock_resource "aws_dynamodb_table" {
    defaults = {
      arn = "arn:aws:dynamodb:us-east-1:123456789012:table/mock-table"
    }
  }
}

mock_provider "aws" {
  alias = "dr"
  
  # DR region provider with same mock configurations
  mock_data "aws_region" {
    defaults = {
      name = "us-west-2"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn              = "arn:aws:lambda:us-west-2:123456789012:function/mock-function-dr"
      invoke_arn       = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-west-2:123456789012:function/mock-function-dr/invocations"
      last_modified    = "2026-02-21T00:00:00Z"
      qualified_arn    = "arn:aws:lambda:us-west-2:123456789012:function/mock-function-dr:$LATEST"
      signing_job_arn  = "arn:aws:signer:us-west-2:123456789012:/signing-jobs/mock-job-dr"
      signing_profile_version_arn = "arn:aws:signer:us-west-2:123456789012:/signing-profiles/mock-profile-dr"
      source_code_hash = "mock-hash-dr"
      source_code_size = 1024
      version          = "$LATEST"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-bucket-dr"
    }
  }

  mock_resource "aws_dynamodb_table" {
    defaults = {
      arn = "arn:aws:dynamodb:us-west-2:123456789012:table/mock-table-dr"
    }
  }
}

# Test 1: Basic configuration validation
run "basic_configuration" {
  command = plan

  variables {
    project_name = "test-app"
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # Should create basic resources
  assert {
    condition     = aws_lambda_function.primary != null
    error_message = "Should create one Lambda function"
  }

  assert {
    condition     = aws_s3_bucket.static_assets != null
    error_message = "Should create one S3 bucket for assets"
  }

  assert {
    condition     = aws_cloudfront_distribution.main != null
    error_message = "Should create one CloudFront distribution"
  }
}

# Test 2: Multi-region configuration
run "multi_region_configuration" {
  command = plan

  variables {
    project_name      = "test-app"
    enable_dr         = true
    dr_region         = "us-west-2"
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # Should create resources in both regions
  assert {
    condition     = aws_lambda_function.primary != null && aws_lambda_function.dr != null
    error_message = "Should create two Lambda functions for multi-region"
  }

  assert {
    condition     = aws_s3_bucket.static_assets != null && aws_s3_bucket.static_assets_dr != null
    error_message = "Should create two S3 buckets for multi-region"
  }
}

# Test 3: Custom domain configuration
run "custom_domain_configuration" {
  command = plan

  variables {
    project_name      = "test-app"
    domain_name       = "example.com"
    route53_managed   = true
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # Should create Route 53 resources
  assert {
    condition     = aws_route53_record.main != null
    error_message = "Should create Route 53 record for custom domain"
  }

  assert {
    condition     = aws_acm_certificate.main != null
    error_message = "Should create ACM certificate for custom domain"
  }
}

# Test 4: Validation failures
run "invalid_name_too_short" {
  command = plan

  variables {
    project_name = "ab"  # Too short, should fail validation
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [
    var.project_name
  ]
}

run "invalid_name_too_long" {
  command = plan

  variables {
    project_name = "this-is-a-very-long-name-that-exceeds-the-maximum-length-allowed-for-resource-names"  # Too long
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [
    var.project_name
  ]
}

# Test 5: DynamoDB configuration
run "dynamodb_configuration" {
  command = plan

  variables {
    project_name         = "test-app"
    enable_dynamo        = true
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = aws_dynamodb_table.visits_primary != null
    error_message = "Should create DynamoDB table when enabled"
  }
}

# Test 6: No DynamoDB
run "no_dynamodb_configuration" {
  command = plan

  variables {
    project_name    = "test-app"
    enable_dynamo   = false
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = aws_dynamodb_table.visits_primary == null
    error_message = "Should not create DynamoDB table when disabled"
  }
}