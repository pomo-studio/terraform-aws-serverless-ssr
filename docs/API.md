# API Reference

Complete reference for all module inputs and outputs.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Providers

This module requires two AWS provider aliases:

| Name | Purpose | Example Region |
|------|---------|----------------|
| `aws.primary` | Primary region for all resources | us-east-1 |
| `aws.dr` | DR region for failover resources | us-west-2 |

**Example provider configuration:**

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

## Inputs

### Required Inputs

| Name | Description | Type | Constraints |
|------|-------------|------|-------------|
| `project_name` | Project name used for resource naming | `string` | 3-20 characters, lowercase alphanumeric and hyphens only |
| `domain_name` | Base domain name (must exist in Route 53) | `string` | Valid domain format |
| `subdomain` | Subdomain for the application | `string` | Valid subdomain format |

### Optional Inputs

#### Environment

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `environment` | Environment name (e.g., dev, staging, prod) | `string` | `"prod"` |
| `tags` | Additional tags to apply to all resources | `map(string)` | `{}` |

#### Regions

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `primary_region` | AWS region for primary deployment | `string` | `"us-east-1"` |
| `dr_region` | AWS region for DR deployment | `string` | `"us-west-2"` |
| `enable_dr` | Enable disaster recovery region | `bool` | `true` |

**Note**: Set `enable_dr = false` to deploy single-region for cost savings.

#### Domain

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `custom_domain` | Custom domain for CloudFront (defaults to subdomain.domain_name) | `string` | `""` |

#### Lambda Configuration

| Name | Description | Type | Default | Range |
|------|-------------|------|---------|-------|
| `lambda_memory_size` | Lambda function memory in MB | `number` | `512` | 128-10240 |
| `lambda_timeout` | Lambda function timeout in seconds | `number` | `10` | 3-900 |

**Memory recommendations:**
- 512 MB: Small apps, simple SSR
- 1024 MB: Medium apps, moderate complexity
- 2048+ MB: Large apps, complex rendering

#### CI/CD

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `create_ci_cd_user` | Create IAM user for CI/CD pipelines | `bool` | `true` |

**Note**: Set to `false` if using OIDC or existing IAM roles.

## Outputs

### Application

| Name | Description | Sensitive |
|------|-------------|-----------|
| `application_url` | Full URL where application is accessible | No |
| `cloudfront_distribution_id` | CloudFront distribution ID (for cache invalidation) | No |

### Lambda Functions

| Name | Description | Sensitive |
|------|-------------|-----------|
| `lambda_function_name_primary` | Primary region Lambda function name | No |
| `lambda_function_name_dr` | DR region Lambda function name (if enabled) | No |
| `lambda_function_url_primary` | Primary Lambda function URL | No |
| `lambda_function_url_dr` | DR Lambda function URL (if enabled) | No |

### Storage

| Name | Description | Sensitive |
|------|-------------|-----------|
| `s3_bucket_static` | S3 bucket name for static assets | No |
| `s3_bucket_deployments_primary` | Primary region S3 bucket for deployments | No |
| `s3_bucket_deployments_dr` | DR region S3 bucket for deployments (if enabled) | No |

### Database

| Name | Description | Sensitive |
|------|-------------|-----------|
| `dynamodb_table_name` | DynamoDB table name | No |
| `dynamodb_table_arn` | DynamoDB table ARN | No |

### CI/CD

| Name | Description | Sensitive |
|------|-------------|-----------|
| `cicd_aws_access_key_id` | CI/CD IAM user access key ID | No |
| `cicd_aws_secret_access_key` | CI/CD IAM user secret access key | Yes |

**Note**: Store these securely in GitHub Secrets or your CI/CD platform.

### Configuration Bundle

| Name | Description | Sensitive |
|------|-------------|-----------|
| `app_config` | Complete configuration object for application deployment | Yes |

**Structure**:
```json
{
  "lambda_function_name_primary": "...",
  "lambda_function_name_dr": "...",
  "s3_bucket_static": "...",
  "s3_bucket_deployments_primary": "...",
  "s3_bucket_deployments_dr": "...",
  "cloudfront_distribution_id": "...",
  "dynamodb_table_name": "...",
  "primary_region": "...",
  "dr_region": "..."
}
```

**Usage**:
```bash
terraform output -json app_config > config/infra-outputs.json
```

## Examples

### Minimal Configuration

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.2"

  project_name = "my-app"
  domain_name  = "example.com"
  subdomain    = "app"
}
```

### Single-Region (Cost Optimized)

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.2"

  project_name = "my-app"
  domain_name  = "example.com"
  subdomain    = "app"

  enable_dr = false  # No DR region
}
```

### Production Configuration

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.2"

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

  # Lambda (higher resources for production)
  lambda_memory_size = 1024
  lambda_timeout     = 30

  # CI/CD
  create_ci_cd_user = true

  # Tags
  tags = {
    Team        = "Platform"
    CostCenter  = "Engineering"
    Compliance  = "HIPAA"
  }
}
```

### Using OIDC Instead of IAM User

```hcl
module "ssr" {
  source  = "pomo-studio/serverless-ssr/aws"
  version = "~> 2.2"

  project_name = "my-app"
  domain_name  = "example.com"
  subdomain    = "app"

  create_ci_cd_user = false  # Use OIDC or existing IAM role
}
```

## Validation Rules

### project_name

- Length: 3-20 characters
- Format: Lowercase letters, numbers, hyphens only
- Cannot start/end with hyphen

**Valid**: `my-app`, `prod-web`, `api-v2`
**Invalid**: `MyApp`, `my_app`, `-myapp`, `a`

### domain_name

Must be a valid domain name registered in Route 53 in the same AWS account.

### subdomain

Standard subdomain format (alphanumeric and hyphens).

## Resource Naming Convention

All resources follow this pattern:

```
{project_name}-{resource_type}-{region}
```

**Examples**:
- Lambda: `my-app-primary`
- S3 static: `my-app-static-{account-id}`
- DynamoDB: `my-app-visits`

## See Also

- [Getting Started Guide](GETTING_STARTED.md)
- [Architecture Overview](ARCHITECTURE.md)
- [Examples](../examples/)
