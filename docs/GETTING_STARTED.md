# Getting Started

This guide walks you through deploying your first serverless SSR application using this Terraform module.

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- A domain name configured in Route 53
- Node.js (if deploying an application)

## Step 1: Create Infrastructure

Create a new directory for your infrastructure code:

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
  source = "github.com/pomo-studio/serverless-ssr-module"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  project_name = "my-app"
  domain_name  = "example.com"
  subdomain    = "app"

  enable_dr         = true
  create_ci_cd_user = false  # prefer OIDC; set true only for legacy IAM key auth
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

## Step 2: Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

The deployment will create:
- Lambda functions in primary and DR regions
- CloudFront distribution with failover
- S3 buckets for static assets and deployments
- DynamoDB global table
- ACM certificates for your custom domain
- (Optional) IAM user for CI/CD

## Step 3: Get Configuration

Export the infrastructure configuration for your application:

```bash
terraform output -json app_config > ~/my-app/config/infra-outputs.json
```

This file contains all the resource IDs and configuration your application needs.

## Step 4: Deploy Your Application

### Option A: Use the Template

Clone and deploy the companion application template:

```bash
git clone https://github.com/pomo-studio/serverless-ssr-app.git my-app
cd my-app

# Copy infrastructure config
cp ~/my-app-infra/infra-outputs.json config/

# Install and deploy
npm install
./scripts/deploy.sh
```

### Option B: Use Your Own Application

Configure your application to read from `config/infra-outputs.json` and deploy:

```bash
# Build for Lambda
NITRO_PRESET=aws-lambda npm run build

# Package
cd .output
zip -r ../lambda.zip .

# Deploy to both regions
aws lambda update-function-code \
  --function-name $(jq -r '.lambda_function_name_primary' ../config/infra-outputs.json) \
  --zip-file fileb://../lambda.zip

# Sync static assets to S3
aws s3 sync .output/public/ \
  s3://$(jq -r '.s3_bucket_static' ../config/infra-outputs.json)/ \
  --delete

# Note: CloudFront routes /_nuxt/* to S3. In Nuxt/Vite projects, place images and
# other assets in assets/ (not public/) so Vite bundles them to _nuxt/[hash].ext.
# Files placed in public/ at paths like /images/* will route to Lambda instead of S3.

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(jq -r '.cloudfront_distribution_id' ../config/infra-outputs.json) \
  --paths "/*"
```

## Step 5: Verify Deployment

Visit your application URL (from `application_url` output):

```bash
terraform output application_url
```

## Next Steps

- [Configure CI/CD](CI_CD.md) for automated deployments
- [Architecture Overview](ARCHITECTURE.md) to understand the infrastructure
- [API Reference](API.md) for all configuration options

## Troubleshooting

### Domain Not Resolving

DNS propagation can take 5-10 minutes. Check your Route 53 hosted zone for the correct records.

### Lambda Function Errors

Check CloudWatch Logs for the Lambda function:

```bash
aws logs tail /aws/lambda/$(terraform output -raw lambda_function_name_primary) --follow
```

### CloudFront Cache Issues

Invalidate the cache manually:

```bash
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```
