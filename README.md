# terraform-aws-serverless-ssr

Terraform module for deploying SSR applications (Nuxt, Next.js, Nitro) on AWS Lambda with multi-region failover.

- Multi-region Lambda (us-east-1 + us-west-2) with CloudFront automatic failover — no Route 53 health checks needed
- Stale-While-Revalidate caching for instant page loads while Lambda refreshes content in the background
- Direct Lambda URL access blocked by origin-secret — only CloudFront can invoke the function
- Custom domain + ACM certificate fully automated for Route 53-managed zones
- Optional DynamoDB global table for visit/session data, replicated to DR automatically

**Registry**: `pomo-studio/serverless-ssr/aws` | **Live example**: [ssr.pomo.dev](https://ssr.pomo.dev)

---

## What it provisions

```
CloudFront (Global CDN + Origin Groups)
├── Primary  us-east-1
│   ├── Lambda Function URL  — SSR handler
│   ├── S3  — static assets + Lambda deployment bucket
│   └── DynamoDB  — global table (replicated to DR)
└── DR  us-west-2
    ├── Lambda Function URL  — failover target
    └── S3  — Lambda deployment bucket
```

CloudFront origin groups fail over automatically on any 5xx response — no Route 53 health checks required.

**Stale-While-Revalidate (SWR) caching** gives instant page loads from CloudFront edge locations while Lambda refreshes content in the background. See [Caching Guide](docs/CACHING.md) for details.

Optional: ACM certificate + Route 53 alias record for a custom domain.

---

## Usage

### Minimal — no custom domain

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.4"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name = "my-app"
}
```

Output: `https://d111111abcdef8.cloudfront.net`

---

### Custom domain (Route 53 managed)

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.4"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name    = "my-app"
  domain_name     = "example.com"
  subdomain       = "app"          # omit for root domain
  route53_managed = true
}
```

Output: `https://app.example.com` — DNS and ACM certificate created automatically.

---

### Custom domain (external DNS)

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.4"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name    = "my-app"
  domain_name     = "example.com"
  subdomain       = "app"
  route53_managed = false
}
```

Terraform outputs the CNAME and ACM validation records to add at your registrar. See [`dns_validation_records`](#outputs) and [`dns_cloudfront_record`](#outputs).

---

### AWS provider configuration

Both providers are required regardless of whether DR is enabled:

```hcl
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}
```

---

## Integration tests (deployed behavior)

The module includes a lightweight integration test script that validates:
- CloudFront → Lambda access (OAC + `InvokeFunction` permissions)
- `POST /api/*` behavior (cache behavior + origin group bypass)
- Optional: direct Lambda Function URL access is blocked (expects 403)

Scope boundary:
- This module is for SSR web delivery.
- API POST workflows should live in dedicated API modules (for example AppSync/API Gateway), not in SSR routing behavior.
- See `docs/ROADMAP.md` for boundary and backlog notes.

Internal note:
- Decomposition has started behind the existing facade contract (no input/output break); Lambda, DNS/ACM, storage, and CloudFront resources are now managed via internal submodules.

Run against a deployed distribution:

```bash
cd /home/apitanga/code/terraform-aws-serverless-ssr
BASE_URL=https://your-distribution.example.com make test-integration
```

Optional inputs:

```bash
BASE_URL=https://your-distribution.example.com \
API_PATH=/api/health \
POST_PAYLOAD='{"ping":"pong"}' \
GET_PATH=/ \
EXPECT_GET_STATUS=200 \
EXPECT_POST_STATUS=200 \
EXPECT_API_CACHE_CONTROL=no-store \
LAMBDA_FUNCTION_URL=https://xxxx.lambda-url.us-east-1.on.aws \
make test-integration
```

The script lives at `tests/integration.sh` and can be wired into CI once you choose a target environment.

GET-only CI gate:
- Workflow: `.github/workflows/integration-get.yml`
- Required repo variable: `SSR_INTEGRATION_BASE_URL` (for example `https://pomo.dev`)
- Optional repo variable: `SSR_EXPECT_GET_STATUS` (defaults to `200`)

## CI/CD authentication

### Recommended — OIDC (no static credentials)

Set `create_ci_cd_user = false` and create an IAM role that trusts your CI provider.

For GitHub Actions:

```hcl
module "ssr" {
  # ...
  create_ci_cd_user = false
}
```

Then in your workflow:

```yaml
permissions:
  id-token: write
  contents: read

- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions-my-app
    aws-region: us-east-1
```

See the [pomo-ssr deploy workflow](https://github.com/pomo-studio/pomo-ssr/blob/main/.github/workflows/deploy.yml) for a complete example.

### Legacy — IAM user (not recommended)

```hcl
module "ssr" {
  # ...
  create_ci_cd_user = true
}
```

Outputs `cicd_aws_access_key_id` and `cicd_aws_secret_access_key`. Store as secrets, rotate regularly.

---

## Static assets

CloudFront routes `/_nuxt/*` to S3 and everything else to Lambda. In Nuxt/Vite projects:

- **Put images in `assets/`** — Vite bundles them to `_nuxt/[hash].ext`, served from S3 via the `/_nuxt/*` behavior.
- **Avoid `/images/*` in `public/`** — those paths have no S3 behavior and will hit Lambda, returning a 404.

The `/favicon.ico` path has its own S3 behavior and is the only `public/` exception.

---

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | `string` | required | Used as prefix for all resource names. 3–20 chars, lowercase alphanumeric + hyphens. |
| `domain_name` | `string` | `null` | Base domain (e.g. `example.com`). Null = use CloudFront URL. |
| `subdomain` | `string` | `null` | Subdomain (e.g. `app`). Null = root domain. |
| `route53_managed` | `bool` | `false` | Auto-manage DNS and ACM validation in Route 53. |
| `primary_region` | `string` | `us-east-1` | Primary AWS region. |
| `dr_region` | `string` | `us-west-2` | DR AWS region. |
| `enable_dr` | `bool` | `true` | Deploy DR Lambda and S3. Disable for dev/staging to reduce cost. |
| `enable_dynamo` | `bool` | `true` | Deploy DynamoDB global table. Set false if your app has no persistence needs or uses an external database. |
| `lambda_memory_size` | `number` | `512` | Lambda memory in MB. |
| `lambda_timeout` | `number` | `10` | Lambda timeout in seconds. |
| `create_ci_cd_user` | `bool` | `false` | Create IAM user with deployment credentials. Set false when using OIDC. |
| `environment` | `string` | `prod` | Environment tag applied to all resources. |
| `tags` | `map(string)` | `{}` | Additional tags for all resources. |

---

## Outputs

### Application URL

| Output | Description |
|---|---|
| `application_url` | Final URL — custom domain if configured, otherwise CloudFront. |

### `app_config` — deployment bundle

The `app_config` output contains everything a deploy script needs. Write it to a JSON file and parse it:

```bash
terraform output -json > config/infra-outputs.json
```

```json
{
  "app_config": {
    "value": {
      "project_name": "my-app",
      "primary_region": "us-east-1",
      "dr_region": "us-west-2",
      "lambda": {
        "primary": { "function_name": "...", "s3_bucket": "..." },
        "dr":      { "function_name": "...", "s3_bucket": "..." }
      },
      "static_assets": { "s3_bucket": "..." },
      "cloudfront":    { "distribution_id": "..." },
      "dynamodb":      { "table_name": "my-app-visits" }
    }
  }
}
```

### All outputs

| Output | Description |
|---|---|
| `app_config` | Complete deployment bundle (see above). |
| `application_url` | Application URL. |
| `cloudfront_distribution_id` | For cache invalidation. |
| `cloudfront_domain_name` | Raw CloudFront hostname. |
| `lambda_function_name_primary` | Primary Lambda name. |
| `lambda_function_name_dr` | DR Lambda name. |
| `dynamodb_table_name` | DynamoDB table name. |
| `dns_validation_records` | ACM CNAME records (only when `route53_managed = false`). |
| `dns_cloudfront_record` | CloudFront alias/CNAME record (only when `route53_managed = false`). |
| `cicd_aws_access_key_id` | IAM key ID (only when `create_ci_cd_user = true`). |
| `cicd_aws_secret_access_key` | IAM secret (sensitive, only when `create_ci_cd_user = true`). |

---

## Requirements

| Tool | Version |
|---|---|
| Terraform | `>= 1.5.0` |
| AWS provider | `~> 5.0` |

---

## Design decisions

**CloudFront origin groups for DR failover** — 5xx responses automatically retry against the DR Lambda. No Route 53 health checks, no DNS TTL delay.

**Stale-While-Revalidate caching** — CloudFront serves cached responses instantly while Lambda refreshes content in the background. Lambda controls freshness via `Cache-Control` headers; the module's cache policy honours them.

**Origin-secret header instead of OAC** — CloudFront injects a `X-Origin-Secret` header on every request; the Lambda checks it and returns 403 if absent. Direct Lambda URL access is blocked without the AWS_IAM signing complexity.

**Both providers required even with `enable_dr = false`** — provider aliases are declared at plan time; Terraform requires both `aws.primary` and `aws.dr` to be passed regardless. Use the same region for both in dev/staging to avoid the cost of a second region.

**Static assets on S3, SSR on Lambda** — `/_nuxt/*` and `/favicon.ico` have dedicated S3 cache behaviors with long TTLs. Everything else hits Lambda. Keeps CDN costs low and Lambda invocations focused on actual SSR work.

## Documentation

- [Getting Started](docs/GETTING_STARTED.md) — first deployment walkthrough
- [Architecture](docs/ARCHITECTURE.md) — CloudFront origin groups, failover, cost breakdown
- [Caching](docs/CACHING.md) — Stale-While-Revalidate configuration and tuning
- [Domain Setup](docs/DOMAIN_SETUP.md) — migrating a domain to Route 53
- [API Reference](docs/API.md) — full input/output reference
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Examples

- [examples/basic/](examples/basic/) — minimal, no domain
- [examples/complete/](examples/complete/) — all options enabled

## Related

- [pomo-ssr](https://github.com/pomo-studio/pomo-ssr) — demo site using this module (Nuxt 3, multi-region, OIDC CI/CD)
- [pomo-dev](https://github.com/pomo-studio/pomo-dev) — postmodern. Terraform pattern library, production site using this module

---

MIT
