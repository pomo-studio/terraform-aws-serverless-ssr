# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## Upgrade notes

### Migrating from v2.4.8 (or earlier) to v2.4.9+

Starting with v2.4.9, this module was decomposed into registry-published child modules (`ssr-*` and `dynamodb-global-table`) instead of defining all resources inline. When upgrading across that boundary:

- **Always review `terraform plan` carefully** before applying — decomposition can surface as unexpected destroy/recreate of resources if Terraform cannot map old addresses to the new child-module addresses.
- **Use `moved` blocks** to remap resource addresses where the plan shows replacements that should be in-place moves.

The decomposition landed in [`90caf19`](https://github.com/pomo-studio/terraform-aws-serverless-ssr/commit/90caf19f6928930266bfb4f763fd318b30395a08) (2026-02-26), which removed the local `modules/` submodules and pointed the root module at the registry-published `ssr-*` children.

## [v2.8.0] - 2026-10-02

**Upgrade risk: none expected.** New optional input only. With the default (`[]`) the plan is unchanged; verified with speculative plans against every current consumer. Upgrade directly from v2.7.x; roll back by pinning `= 2.7.4`.

### Added

- `additional_domain_names`: extra hostnames in the same domain, e.g. `["www.example.com"]` for a site on the bare domain. They are added to the certificate, get alias records when `route53_managed = true`, and are redirected with a 301 to the main domain (path and every query parameter kept; parameter order is not preserved). Checked at plan time: lowercase hostnames, no duplicates, subdomains of `domain_name`, not the site's own domain.
- `dns_additional_records` output, for setups where Route 53 does not manage the zone.

### Changed

- Child module pins: `ssr-dns` `0.3.0` → `0.4.0`, `ssr-cloudfront` `0.3.6` → `0.4.0` (the feature above; `ssr-dns` 0.3.1 and 0.3.2 were documentation-only), `ssr-cloudfront-support` `0.2.4` → `0.2.6` (Dependabot).

## [v2.7.4] - 2026-09-27

*Entry added after release; it was missing from the v2.7.4 tag.*

**Upgrade risk: none expected.** No resource additions or removals; existing stacks see no plan change. Upgrade directly from v2.7.x; roll back by pinning `= 2.7.3`.

### Fixed

- The bootstrap placeholder Lambda now starts ([#35](https://github.com/pomo-studio/terraform-aws-serverless-ssr/issues/35)). `$${var.project_name}` rendered a literal `${var.project_name}` into the JavaScript, so the function failed to initialize (`SyntaxError: Unexpected token 'var'`) and a fresh stack returned 502 until the first app deploy.
- The bootstrap S3 objects (`lambda/function.zip`) now ignore later `etag`/`source` changes. App deploys upload to the same key, so changing the placeholder code or the module's install path could otherwise re-upload the placeholder over the deployed app's zip on the next apply.

## [v2.7.3] - 2026-09-26

**Upgrade risk: none expected for DR-enabled stacks (the default).** Upgrade directly from v2.7.x; roll back by pinning `= 2.7.2`. With `enable_dr = true` the only plan change is three replication IAM resources *moving* to indexed addresses (`moved` blocks, no replacement); verified with speculative plans against a live DR-enabled consumer.

### Fixed

- `enable_dr = false` now works ([#29](https://github.com/pomo-studio/terraform-aws-serverless-ssr/issues/29)). Previously apply failed twice: CloudFront got DR origins with an empty `domain_name`, and the S3 replication IAM policy got an empty resource ARN. Fixed in the child modules; without DR, CloudFront routes straight to the primary origins with no origin groups.

### Changed

- Child module pins: `ssr-cloudfront` `0.3.3` → `0.3.6`, `ssr-storage` `0.2.4` → `0.2.6` (the #29 fixes; the other versions in these ranges are documentation-only).
- Unit test for `enable_dr = false`.

## [v2.7.2] - 2026-09-26

**Upgrade risk: none expected.** No resource, input or output changes. Upgrade directly from v2.7.x; roll back by pinning `= 2.7.1`. Verified with a speculative plan against a live consumer (monument-training, `enable_dr = true`, `enable_dynamo = false`): v2.7.1 and this release produce identical plans. Both show the same two in-place `aws_s3_bucket_policy` updates, a pre-existing perpetual diff where AWS normalizes the OAI `CanonicalUser` principal to its ARN.

### Changed

- Child module pins: `ssr-cloudfront-support` `0.2.0` → `0.2.4`, `ssr-cloudfront` `0.3.0` → `0.3.3`, `ssr-lambda` `0.2.0` → `0.2.3`, `ssr-storage` `0.2.0` → `0.2.4`, `dynamodb-global-table` `1.0.1` → `1.0.5`. Every change in these ranges is documentation (variable/output descriptions, changelogs, READMEs); no resource logic changed.

### Fixed

- Documented the `x-amz-content-sha256` requirement for `POST`, `PUT` and `PATCH` requests to `/api/*` ([#30](https://github.com/pomo-studio/terraform-aws-serverless-ssr/issues/30)). Requests with a body were rejected with a SigV4 signature mismatch because CloudFront's OAC does not hash the payload; the caller must send the hash. No infrastructure change.
- `tests/integration.sh` now sends `x-amz-content-sha256` with its `POST` check and uses `--data-binary`, so the check passes against a correctly deployed stack. New optional `EXPECT_UNHASHED_POST_STATUS` confirms that unhashed bodies are rejected.

## [v2.7.1] - 2026-09-12

### Added

- terraform-docs-generated interface documentation in README (Requirements/Providers/Inputs/Outputs) with a CI drift check.

## [v2.7.0] - 2026-09-06

### Added

- `static_root_path_patterns` — root paths served from the static assets origin rather than the SSR Lambda. Previously only `/favicon.ico` was routed, so `robots.txt`, `sitemap.xml` and `apple-touch-icon.png` were uploaded to S3 but returned 404. Defaults to `["/favicon.ico"]`, preserving existing behaviour.

### Changed

- Child module pin: `ssr-cloudfront` `= 0.2.0` → `= 0.3.0`

## [v2.6.0] - 2026-09-06

### Added

- `certificate_arn` input — attach an existing ACM certificate instead of issuing one. Skips the certificate request, validation record, and validation wait. Enables reusing a shared or wildcard certificate, and standing up a site whose domain is not yet delegated to Route 53.

### Changed

- Child module pin: `ssr-dns` `= 0.2.0` → `= 0.3.0`. This also advances past the docs-only `v0.2.1` and `v0.2.2`, and picks up the AWS provider constraint widening (`~> 5.0` → `>= 5.0, < 7.0`) that shipped in `ssr-dns` v0.2.0.

## [v2.5.2] - 2026-09-05

### Added

- CHANGELOG.md

## [v2.5.1] - 2026-09-05

### Changed

- Child module pins: `ssr-*` `= 0.1.0` → `= 0.2.0` and `dynamodb-global-table` `= 1.0.0` → `= 1.0.1`; module composition now resolves against AWS provider v6
- Lambda runtime: `nodejs20.x` → `nodejs22.x`

## [v2.5.0] - 2026-09-04

### Changed

- Provider version constraints: AWS `>= 5.0, < 7.0`, `archive` `>= 2.4, < 3.0`, `random` `>= 3.0, < 4.0`
- Modernized CI/release workflows — replaced deprecated `create-release@v1` action

### Added

- `.tflint.hcl` configuration
- README badges

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

---

> Historical releases are documented in [GitHub Releases](https://github.com/pomo-studio/terraform-aws-serverless-ssr/releases).

[2.4.7]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.6...v2.4.7
[2.4.9]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.8...v2.4.9
[2.4.8]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.7...v2.4.8
[2.4.6]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.4.5...v2.4.6
[2.4.0]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.2...v2.4.0
[2.3.2]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/pomo-studio/terraform-aws-serverless-ssr/releases/tag/v2.3.0
