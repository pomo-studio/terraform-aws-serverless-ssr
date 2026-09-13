# Stewardship & Trust

This document explains what you can and cannot expect from
`terraform-aws-serverless-ssr` as an open-source module, and the commitments we
make to anyone who deploys it.

## What this module is

A composable Terraform building block for server-side rendered web delivery on
AWS. It wires together CloudFront, Lambda, S3, and optional DynamoDB into a
working baseline. It is **not** a managed service, a platform SLA, or a
substitute for your own architecture and security review.

## What we commit to

### 1. Honest scope

- We document what the module provisions and what it deliberately leaves out.
- We label known limitations: DR failover is for eligible SSR/static requests,
  `/api/*` POST routes bypass origin groups, and authentication/API concerns
  belong in separate modules.
- We keep [ROADMAP.md](docs/ROADMAP.md) current with module boundaries and the
  backlog.

### 2. Semantic versioning and changelogs

- Versions follow [Semantic Versioning](https://semver.org/).
- Every release is recorded in [CHANGELOG.md](CHANGELOG.md).
- Breaking changes — including new required inputs, removed outputs, or risky
  upgrades — get explicit migration notes.

### 3. Security by default

- Examples use OIDC and scoped IAM roles, not long-lived access keys.
- The module blocks direct Lambda Function URL access; only CloudFront can
  invoke the SSR handler.
- Security fixes are published promptly and documented in the changelog.

### 4. Transparent runtime lifecycle

- We track AWS Lambda runtime deprecation and announce runtime upgrades in the
  changelog.
- We will not silently move to a new major runtime in a patch release.

### 5. Source ownership

- All resources are plain Terraform. You can read, fork, replace, or vendor the
  module.
- There is no hidden control plane or remote dependency outside the Terraform
  Registry and your own AWS account.

## What we do not commit to

- **Production guarantee.** Every serious deployment needs its own threat model,
  DR testing, monitoring, and operational runbook. This module is a starting
  point, not a certification.
- **Free support SLA.** Issues and pull requests are handled as open-source best
  effort. For guaranteed response times, use a paid support arrangement.
- **Backward compatibility forever.** We follow semver and provide migration
  windows for breaking changes, but we will eventually drop deprecated runtimes,
  inputs, or AWS provider versions.

## How we test

- Terraform validation and linting run on every pull request.
- A dependency-free local regression test (`node --test tests/bootstrap.test.cjs`)
  extracts and renders the actual bootstrap code without AWS credentials.
- Integration tests against a real deployment live in `tests/integration.sh`;
  they are optional because they require a target environment.
- We run the integration suite against our own reference deployments before
  major releases.

## How to report concerns

- **Security issues:** email `contact@pomo.studio` with `[security]` in the
  subject. Do not open public issues for vulnerabilities.
- **Bugs and regressions:** open a GitHub issue with the module version, AWS
  provider version, Terraform version, and a minimal reproduction.
- **Design questions:** open a GitHub discussion before a large pull request.

## Using this module in production

Before relying on it for a production workload, we recommend:

1. Pin an exact module version, not a floating constraint.
2. Read the changelog for the version you are on.
3. Run `terraform plan` in a non-production environment first.
4. Test failover by simulating a primary-region failure and observing CloudFront
   behavior.
5. Verify your own backup, recovery, and monitoring plans separately from this
   module.
6. Review the IAM policies the module creates and confirm they match your
   organization's least-privilege posture.

## License

MIT — see [LICENSE](LICENSE).
