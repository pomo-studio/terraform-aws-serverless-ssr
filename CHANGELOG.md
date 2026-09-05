# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## Upgrade notes

### Migrating from v2.4.8 (or earlier) to v2.4.9+

Starting with v2.4.9, this module was decomposed into registry-published child modules (`ssr-*` and `dynamodb-global-table`) instead of defining all resources inline. When upgrading across that boundary:

- **Always review `terraform plan` carefully** before applying — decomposition can surface as unexpected destroy/recreate of resources if Terraform cannot map old addresses to the new child-module addresses.
- **Use `moved` blocks** to remap resource addresses where the plan shows replacements that should be in-place moves.

See [PR #4](https://github.com/pomo-studio/terraform-aws-serverless-ssr/pull/4) for the decomposition work.

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

---

> Historical releases are documented in [GitHub Releases](https://github.com/pomo-studio/terraform-aws-serverless-ssr/releases).
