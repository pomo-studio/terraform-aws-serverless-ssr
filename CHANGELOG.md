# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.4] - 2026-02-22

### Fixed
- **AWS_IAM authentication failure**: Changed origin request policy from `whitelist` to `allViewer`
- The restrictive whitelist policy was preventing CloudFront from forwarding necessary signing headers (like `Authorization`) to Lambda function URLs with AWS_IAM auth
- CloudFront automatically excludes problematic body headers (`Content-Length`, `Transfer-Encoding`) when using `allViewer`
- This fixes the 403 Forbidden errors when accessing websites via CloudFront

## [2.4.3] - 2026-02-22

### Fixed
- **CloudFront header conflict**: Removed `X-Origin-Region` from origin request policy whitelist
- The header cannot be both a custom header AND a forward header in CloudFront
- This fixes AWS validation error: "Header Name with value X-Origin-Region is not allowed as both an origin custom header and a forward header"
- Restores pre-v2.4.1 behavior where `X-Origin-Region` was only a custom header for region identification

## [2.4.2] - 2026-02-22

### Changed
- Extracted `terraform {}` block from `main.tf` into `versions.tf`
- Added value-prop bullets and Registry badge to README
- Added `## Design decisions` section to README
- Updated usage examples to `version = "~> 2.4"`

## [2.4.1] - 2026-02-21

### Fixed
- **Security regression fixed**: Restored `authorization_type = "AWS_IAM"` for Lambda Function URLs
- Added custom `aws_cloudfront_origin_request_policy` that excludes `Content-Length` and `Transfer-Encoding` headers
- Removed `X-Origin-Secret` header validation (no longer needed with AWS_IAM auth)
- Added proper `aws_lambda_permission` resources for CloudFront invocation

### Why This Fix Works
The POST request failures with `authorization_type = "AWS_IAM"` were caused by the `AllViewerExceptHostHeader` policy forwarding body headers (`Content-Length`, `Transfer-Encoding`) that CloudFront modifies after signing requests. The custom origin request policy excludes these problematic headers while maintaining security through AWS IAM authentication.

### Security
- ✅ AWS-enforced IAM authentication restored
- ✅ CloudFront signs all requests to Lambda Function URLs
- ✅ No application-level header validation needed
- ✅ Proper least-privilege permissions via `aws_lambda_permission`

## [2.4.0] - 2026-02-21

### Security Warning
**⚠️ Critical Security Regression**: This version introduced a security regression by changing `authorization_type = "AWS_IAM"` to `authorization_type = "NONE"` with a custom `X-Origin-Secret` header. DO NOT USE this version.

### Changed
- Changed Lambda Function URL `authorization_type` from `"AWS_IAM"` to `"NONE"`
- Added `X-Origin-Secret` header validation in CloudFront origin request policy

### Why This Change Was Made
CloudFront Origin Access Control (OAC) with `authorization_type = "AWS_IAM"` was found to fail for POST requests while working for GET requests. The root cause was that `AllViewerExceptHostHeader` policy forwards body headers (`Content-Length`, `Transfer-Encoding`) that CloudFront modifies after signing, causing signature validation failures.

## [2.3.2] - 2026-02-21

### Fixed
- Fixed CloudFront OAC signing for Lambda Function URLs
- Added proper IAM permissions for CloudFront to invoke Lambda Function URLs
- Updated documentation for multi-region deployment patterns

## [2.3.1] - 2026-02-21

### Added
- Support for CloudFront Origin Access Control (OAC) replacing Origin Access Identity (OAI)
- Added `cloudfront_origin_access_control` resource for Lambda Function URL origins
- Updated IAM policies for OAC-based Lambda invocation

### Changed
- Minimum Terraform version bumped to >= 1.5.0
- Updated AWS provider to ~> 5.0

### Fixed
- Fixed Lambda Function URL CORS configuration
- Improved error handling for multi-region failover scenarios

## [2.3.0] - 2026-02-21

### Added
- Multi-region failover support with CloudFront origin groups
- Stale-While-Revalidate (SWR) caching configuration
- Comprehensive input validation
- Example configurations for Nuxt, Next.js, and Nitro

### Features
- **Global CDN**: CloudFront with edge caching
- **Automatic failover**: Origin groups with 5xx response detection
- **Zero-downtime deployments**: Lambda aliases and traffic shifting
- **Production-ready**: Least-privilege IAM, logging, monitoring

[2.4.0]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.2...v2.4.0
[2.3.2]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/releases/tag/v2.3.0