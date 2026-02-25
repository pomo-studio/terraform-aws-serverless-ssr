# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.4.9] - 2026-02-24

### Fixed
- Added comprehensive `moved` blocks in `moved.tf` to map pre-decomposition root resource addresses to internal submodule addresses.
- Prevented destructive create/destroy churn when upgrading from pre-decomposition versions.

### Why This Release Exists
- `v2.4.8` shipped decomposition refactors without complete state-address migration mappings.
- Existing consumers could see large replacement plans (including site-critical resources) during upgrade.
- `v2.4.9` is the migration safety patch and should be the minimum target for decomposition upgrades.

### Upgrade Notes
- Do not stop on `v2.4.8`.
- Upgrade directly to `v2.4.9` (or later) and review plan output for zero unexpected destroys before apply.

## [2.4.8] - 2026-02-24

### Changed
- Refactored module internals into composed submodules while keeping the root input/output facade:
  - `modules/lambda`
  - `modules/dns`
  - `modules/storage`
  - `modules/cloudfront-support`
  - `modules/cloudfront`
- Rewired root resources/outputs to consume submodule outputs.

### Important
- This release introduced internal address moves and required explicit state migration mappings.
- Consumers should prefer `v2.4.9+` for safe upgrades.

### Changed
- Began internal decomposition of Lambda resources behind the existing root facade:
  - root `lambda.tf` now instantiates internal `modules/lambda` for primary and DR Lambda functions
  - root outputs and permissions now reference module outputs instead of direct root Lambda resources
- Continued decomposition with DNS/ACM extraction:
  - root `route53.tf` now delegates DNS and ACM resources to internal `modules/dns`
  - root CloudFront and DNS outputs now reference module outputs
- Continued decomposition with storage extraction:
  - root `s3.tf` now delegates bucket, policy, and replication resources to internal `modules/storage`
  - root CloudFront, Lambda bootstrap, CI/CD IAM policy, and outputs now reference storage module outputs
- Continued decomposition with CloudFront support extraction:
  - root `cloudfront.tf` now delegates OAI/OAC/origin-request-policy/cache-policy to internal `modules/cloudfront-support`
  - root distribution and storage module wiring now consume cloudfront-support outputs
- Continued decomposition with CloudFront distribution extraction:
  - root `cloudfront.tf` now delegates `aws_cloudfront_distribution.main` to internal `modules/cloudfront`
  - root route53/lambda/iam-cicd/outputs wiring now consume cloudfront module outputs
- No consumer-facing input/output contract changes.

### Internal
- Extended `modules/lambda` inputs (`handler`, `runtime`) and aligned lifecycle behavior for deployment package drift tolerance.
- Updated unit tests to validate Lambda presence through module handles (`module.lambda_primary`, `module.lambda_dr`).

## [2.4.7] - 2026-02-22

### Fixed
- **Restored full OAC Lambda permissions** — OAC signing requires both `lambda:InvokeFunctionUrl` AND `lambda:InvokeFunction`. v2.4.6 only created the former, causing 403 on fresh deployments (existing sites worked due to leftover v2.3.x permissions)
- Permissions now match the proven v2.3.2 set: 4 per region (InvokeFunctionUrl + InvokeFunction, scoped by both source_account and source_arn)

## [2.4.6] - 2026-02-22

### Fixed
- **Restored CloudFront Origin Access Control (OAC) for Lambda Function URLs** — OAC was removed in v2.4.0 and never re-added, leaving CloudFront unable to sign requests to Lambda with `AWS_IAM` auth, causing 403 on all pages
- **Reverted origin request policy to managed `AllViewerExceptHostHeader`** — the custom `lambda_no_body_headers` policy forwarded all viewer headers including `Host`, which broke SigV4 signature validation
- This release restores the proven v2.3.2 security model (OAC + SigV4 + managed policy) while keeping v2.4.x improvements (dedicated `/api/*` cache behavior for POST, SWR cache policy)

### Root Cause
The v2.4.0–v2.4.5 regression chain started when OAC was removed to work around a POST signature failure. The actual POST fix (dedicated `/api/*` cache behavior bypassing origin groups) was correct, but the OAC removal was not — it broke all authentication. Versions 2.4.1–2.4.5 attempted to fix symptoms without restoring the OAC.

### Upgrade Notes
- Users on v2.3.x: upgrade directly to v2.4.7. Skip v2.4.0–v2.4.6.
- Users on v2.4.0–v2.4.6: upgrade to v2.4.7. Fresh deployments on v2.4.6 will have incomplete Lambda permissions.

## [2.4.5] - 2026-02-22

### Fixed
- **AWS_IAM authentication signature mismatch**: Removed `X-Origin-Region` custom header from Lambda origins
- When CloudFront signs requests for AWS_IAM authentication, it includes all headers in the signature calculation
- The `X-Origin-Region` header (added by CloudFront) was changing the signature, causing Lambda to reject requests with 403 errors
- This header was a remnant from v2.4.1 security regression and is not needed for AWS_IAM auth

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

[2.4.7]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.6...v2.4.7
[2.4.9]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.8...v2.4.9
[2.4.8]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.7...v2.4.8
[2.4.6]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.5...v2.4.6
[2.4.0]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.2...v2.4.0
[2.3.2]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/releases/tag/v2.3.0
