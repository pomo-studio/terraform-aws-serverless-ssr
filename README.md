# Serverless SSR Terraform Module

A Terraform module for deploying serverless SSR (Server-Side Rendering) applications on AWS using Lambda, CloudFront, and DynamoDB.

Perfect for hosting Nuxt.js, Next.js, or any Nitro-based framework with automatic failover across multiple regions.

## Features

- 🚀 **Serverless SSR** - Deploy modern frameworks without managing servers
- 🌍 **Multi-Region** - Primary + DR regions with automatic failover
- 🔒 **Custom Domain** - SSL/TLS via ACM certificates
- 📦 **CI/CD Ready** - Optional IAM user for GitHub Actions
- 💾 **Data Persistence** - DynamoDB global table included
- 🧹 **Bootstrap Code** - Works out of the box without pre-built app
- 🔥 **Cache Invalidation** - CloudFront integration for instant updates

## Quick Start

### Minimal Example

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
```

## Usage Guide

### 1. Create Infrastructure

Create a new directory for your infrastructure:

```bash
mkdir my-app-infra
cd my-app-infra
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region provider
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# DR region provider  
provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

# Deploy the module
module "ssr" {
  source = "github.com/apitanga/serverless-ssr-module"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name = "my-app"
  domain_name  = "example.com"
  subdomain    = "app"
  
  enable_dr         = true
  create_ci_cd_user = true
}

# Output configuration for your app
output "app_config" {
  value     = module.ssr.app_config
  sensitive = true
}

output "application_url" {
  value = module.ssr.application_url
}
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Get App Configuration

```bash
terraform output -json app_config > ~/my-app/config/infra-outputs.json
```

### 4. Deploy Your Application

Use the [serverless-ssr-app](https://github.com/apitanga/serverless-ssr-app) template or your own application:

```bash
# Clone app template
git clone https://github.com/apitanga/serverless-ssr-app.git my-app
cd my-app

# Copy infrastructure config
cp ~/my-app-infra/infra-outputs.json config/

# Install and deploy
npm install
./scripts/deploy.sh
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Providers

This module requires two AWS provider aliases:

| Name | Purpose |
|------|---------|
| `aws.primary` | Primary region (e.g., us-east-1) |
| `aws.dr` | DR region (e.g., us-west-2) |

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
| `lambda_function_name_dr` | DR Lambda function name |
| `s3_bucket_static` | S3 bucket for static assets |
| `s3_bucket_deployments_primary` | S3 bucket for Lambda deployments |
| `dynamodb_table_name` | DynamoDB table name |
| `app_config` | Complete configuration for app deployment |
| `cicd_aws_access_key_id` | CI/CD AWS access key |
| `cicd_aws_secret_access_key` | CI/CD AWS secret key (sensitive) |

## Examples

This repository includes working examples:

- [Basic Example](examples/basic/) - Minimal configuration, single region
- [Complete Example](examples/complete/) - All features enabled

## Architecture

```
                         CloudFront
                    (Global CDN + Failover)
                            │
           ┌────────────────┴────────────────┐
           │                                 │
    ┌──────▼──────┐               ┌────────▼──────┐
    │   Primary   │◄─────────────►│      DR       │
    │  us-east-1  │   Failover    │   us-west-2   │
    │             │               │               │
    │  • Lambda   │               │  • Lambda     │
    │  • S3       │               │  • S3         │
    │  • DynamoDB │               │               │
    └─────────────┘               └───────────────┘
```

## Application Deployment

After infrastructure is deployed, use the companion [serverless-ssr-app](https://github.com/apitanga/serverless-ssr-app) template or integrate with your own application:

1. Get the app configuration:
```bash
terraform output -json app_config > config/infra-outputs.json
```

2. Deploy your application:
```bash
npm run build:lambda
./scripts/deploy.sh
```

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [serverless-ssr-app](https://github.com/apitanga/serverless-ssr-app) | Application template for this module |
| [serverless-ssr-pattern](https://github.com/apitanga/serverless-ssr-pattern) | Original project (inspiration) |

## License

MIT
