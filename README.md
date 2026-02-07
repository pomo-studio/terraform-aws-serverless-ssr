# Serverless SSR Terraform Module

A Terraform module for deploying serverless SSR (Server-Side Rendering) applications on AWS using Lambda, CloudFront, and DynamoDB.

## Features

- 🚀 **Serverless SSR** - Deploy Nuxt.js, Next.js, or any Nitro-based framework
- 🌍 **Multi-Region** - Primary + DR regions with automatic failover
- 🔒 **Custom Domain** - SSL/TLS via ACM certificates
- 📦 **CI/CD Ready** - Optional IAM user for GitHub Actions
- 💾 **Data Persistence** - DynamoDB global table included
- 🧹 **Bootstrap Code** - Works out of the box without pre-built app

## Usage

### Basic Example

```hcl
module "ssr" {
  source = "github.com/apitanga/serverless-ssr-module"

  project_name = "my-app"
  domain_name  = "example.com"
  subdomain    = "app"
}
```

### Complete Example

```hcl
module "ssr" {
  source = "github.com/apitanga/serverless-ssr-module"

  # Project
  project_name = "my-production-app"
  environment  = "prod"
  
  # Domain
  domain_name   = "mycompany.com"
  subdomain     = "app"
  custom_domain = "app.mycompany.com"
  
  # Regions
  primary_region = "us-east-1"
  dr_region      = "us-west-2"
  enable_dr      = true
  
  # Lambda
  lambda_memory_size = 1024
  lambda_timeout     = 30
  
  # CI/CD
  create_ci_cd_user = true
}

# Save outputs for your application
resource "local_file" "app_config" {
  content  = jsonencode(module.ssr.app_config)
  filename = "${path.module}/config/infra-outputs.json"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Providers

| Name | Description |
|------|-------------|
| aws.primary | Primary region provider |
| aws.dr | DR region provider (optional) |

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| `project_name` | Project name (3-20 chars, lowercase alphanumeric with hyphens) | `string` |
| `domain_name` | Base domain name | `string` |
| `subdomain` | Subdomain for the application | `string` |

### Optional

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `environment` | Environment name | `string` | `"prod"` |
| `primary_region` | Primary AWS region | `string` | `"us-east-1"` |
| `dr_region` | DR AWS region | `string` | `"us-west-2"` |
| `enable_dr` | Enable DR region | `bool` | `true` |
| `custom_domain` | Custom domain for CloudFront | `string` | `""` |
| `lambda_memory_size` | Lambda memory in MB | `number` | `512` |
| `lambda_timeout` | Lambda timeout in seconds | `number` | `10` |
| `create_ci_cd_user` | Create IAM user for CI/CD | `bool` | `true` |
| `tags` | Additional tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `application_url` | Application URL |
| `cloudfront_distribution_id` | CloudFront distribution ID |
| `lambda_function_name_primary` | Primary Lambda function name |
| `s3_bucket_static` | S3 bucket for static assets |
| `app_config` | Complete configuration for app deployment |
| `cicd_aws_access_key_id` | CI/CD AWS access key |
| `cicd_aws_secret_access_key` | CI/CD AWS secret key (sensitive) |

## Examples

See [examples/](examples/) directory for complete working examples:

- [Basic](examples/basic/) - Minimal configuration
- [Complete](examples/complete/) - All features enabled

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         CloudFront                           │
│                    (Global CDN + Failover)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
       ┌───────────────┴───────────────┐
       │                               │
┌──────▼──────┐              ┌────────▼──────┐
│   Primary   │              │      DR       │
│ us-east-1   │◄────────────►│  us-west-2    │
│             │   Failover   │               │
│ • Lambda    │              │ • Lambda      │
│ • S3        │              │ • S3          │
│ • DynamoDB  │              │               │
└─────────────┘              └───────────────┘
```

## Application Deployment

After infrastructure is deployed:

1. Get the app configuration:
```bash
terraform output -json app_config > config/infra-outputs.json
```

2. Deploy your application:
```bash
npm run build:lambda
./scripts/deploy.sh
```

See [serverless-ssr-app](https://github.com/apitanga/serverless-ssr-app) for a complete application template.

## License

MIT
