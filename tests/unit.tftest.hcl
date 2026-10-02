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
      arn                         = "arn:aws:lambda:us-east-1:123456789012:function/mock-function"
      invoke_arn                  = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function/mock-function/invocations"
      last_modified               = "2026-02-21T00:00:00Z"
      qualified_arn               = "arn:aws:lambda:us-east-1:123456789012:function/mock-function:$LATEST"
      signing_job_arn             = "arn:aws:signer:us-east-1:123456789012:/signing-jobs/mock-job"
      signing_profile_version_arn = "arn:aws:signer:us-east-1:123456789012:/signing-profiles/mock-profile"
      source_code_hash            = "mock-hash"
      source_code_size            = 1024
      version                     = "$LATEST"
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
      arn                         = "arn:aws:lambda:us-west-2:123456789012:function/mock-function-dr"
      invoke_arn                  = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-west-2:123456789012:function/mock-function-dr/invocations"
      last_modified               = "2026-02-21T00:00:00Z"
      qualified_arn               = "arn:aws:lambda:us-west-2:123456789012:function/mock-function-dr:$LATEST"
      signing_job_arn             = "arn:aws:signer:us-west-2:123456789012:/signing-jobs/mock-job-dr"
      signing_profile_version_arn = "arn:aws:signer:us-west-2:123456789012:/signing-profiles/mock-profile-dr"
      source_code_hash            = "mock-hash-dr"
      source_code_size            = 1024
      version                     = "$LATEST"
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
    condition     = module.lambda_primary != null
    error_message = "Should create one Lambda function"
  }

  assert {
    condition     = module.storage != null
    error_message = "Should create one S3 bucket for assets"
  }

  assert {
    condition     = module.cloudfront != null
    error_message = "Should create one CloudFront distribution"
  }
}

# Test 2: Multi-region configuration
run "multi_region_configuration" {
  command = plan

  variables {
    project_name = "test-app"
    enable_dr    = true
    dr_region    = "us-west-2"
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # Should create resources in both regions
  assert {
    condition     = module.lambda_primary != null && module.lambda_dr != null
    error_message = "Should create two Lambda functions for multi-region"
  }

  assert {
    condition     = module.storage != null && module.lambda_dr != null
    error_message = "Should create two S3 buckets for multi-region"
  }
}

# Test 2b: Single-region configuration (#29)
run "single_region_configuration" {
  command = plan

  variables {
    project_name = "test-app"
    enable_dr    = false
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = length(module.lambda_dr) == 0 && length(aws_lambda_function_url.dr) == 0
    error_message = "Should not create a DR Lambda or Function URL when enable_dr = false"
  }

  assert {
    condition     = output.lambda_function_url_dr == null && output.s3_bucket_deployments_dr == null
    error_message = "DR outputs should be null when enable_dr = false"
  }
}

# Test 3: Custom domain configuration
run "custom_domain_configuration" {
  command = plan

  variables {
    project_name    = "test-app"
    domain_name     = "example.com"
    route53_managed = false
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = output.custom_domain_enabled == true && output.route53_managed == false
    error_message = "Should enable custom domain mode with external DNS configuration"
  }
}

run "custom_domain_with_supplied_certificate" {
  command = plan

  variables {
    project_name    = "test-app"
    domain_name     = "example.com"
    subdomain       = "www"
    route53_managed = true
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # The supplied certificate should be attached rather than a new one issued.
  assert {
    condition     = module.dns.certificate_arn == "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
    error_message = "Should attach the supplied certificate ARN"
  }

  assert {
    condition     = length(module.dns.dns_validation_records) == 0
    error_message = "Should not emit validation records when a certificate is supplied"
  }
}

run "rejects_certificate_outside_us_east_1" {
  command = plan

  variables {
    project_name    = "test-app"
    domain_name     = "example.com"
    certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [var.certificate_arn]
}

run "static_root_path_patterns_default" {
  command = plan

  variables {
    project_name = "test-app"
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # Existing callers must see the previous single behaviour unchanged.
  assert {
    condition     = length(var.static_root_path_patterns) == 1 && var.static_root_path_patterns[0] == "/favicon.ico"
    error_message = "Default should preserve the previous single favicon behaviour"
  }
}

# Test 4: Validation failures
run "invalid_name_too_short" {
  command = plan

  variables {
    project_name = "ab" # Too short, should fail validation
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
    project_name = "this-is-a-very-long-name-that-exceeds-the-maximum-length-allowed-for-resource-names" # Too long
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
    project_name  = "test-app"
    enable_dynamo = true
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = length(module.dynamodb) == 1
    error_message = "Should create DynamoDB table when enabled"
  }
}

# Test 6: No DynamoDB
run "no_dynamodb_configuration" {
  command = plan

  variables {
    project_name  = "test-app"
    enable_dynamo = false
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = length(module.dynamodb) == 0
    error_message = "Should not create DynamoDB table when disabled"
  }
}

# additional_domain_names (www alongside the bare domain)
run "additional_domain_names_default_empty" {
  command = plan

  variables {
    project_name    = "test-app"
    domain_name     = "example.com"
    route53_managed = false
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = length(output.dns_additional_records) == 0
    error_message = "No additional records should exist by default"
  }
}

run "additional_domain_names_external_dns" {
  command = plan

  variables {
    project_name            = "test-app"
    domain_name             = "example.com"
    route53_managed         = false
    additional_domain_names = ["www.example.com"]
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  assert {
    condition     = length(output.dns_additional_records) == 1 && output.dns_additional_records[0].name == "www.example.com"
    error_message = "Should emit one manual DNS record for www.example.com"
  }
}

run "additional_domain_names_route53" {
  command = plan

  variables {
    project_name            = "test-app"
    domain_name             = "example.com"
    route53_managed         = true
    additional_domain_names = ["www.example.com"]
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  # Mocks leave domain_validation_options unknown at plan time, which the
  # validation-record for_each cannot accept; the real provider knows the
  # domain names at plan time. Supply them here.
  override_resource {
    target          = module.dns.aws_acm_certificate.main
    override_during = plan
    values = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
      domain_validation_options = [
        { domain_name = "example.com", resource_record_name = "_a.example.com.", resource_record_type = "CNAME", resource_record_value = "_a.acm-validations.aws." },
        { domain_name = "www.example.com", resource_record_name = "_b.www.example.com.", resource_record_type = "CNAME", resource_record_value = "_b.acm-validations.aws." },
      ]
    }
  }

  assert {
    condition     = length(output.dns_additional_records) == 0
    error_message = "Route 53 manages the records, so none should be emitted for manual setup"
  }
}

run "rejects_additional_domain_uppercase" {
  command = plan

  variables {
    project_name            = "test-app"
    domain_name             = "example.com"
    additional_domain_names = ["WWW.example.com"]
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [var.additional_domain_names]
}

run "rejects_additional_domain_outside_domain" {
  command = plan

  variables {
    project_name            = "test-app"
    domain_name             = "example.com"
    additional_domain_names = ["www.other.com"]
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "rejects_additional_domain_without_domain_name" {
  command = plan

  variables {
    project_name            = "test-app"
    additional_domain_names = ["www.example.com"]
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "rejects_additional_domain_equal_to_site_domain" {
  command = plan

  variables {
    project_name            = "test-app"
    domain_name             = "example.com"
    subdomain               = "www"
    additional_domain_names = ["www.example.com"]
  }

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  expect_failures = [data.aws_caller_identity.current]
}
