# Complete Example

Full production setup with custom domain, multi-region DR, and CI/CD.

## What This Deploys

- ✅ CloudFront distribution with custom domain
- ✅ Route53 DNS records (automatic)
- ✅ ACM SSL certificate (automatic validation)
- ✅ Multi-region deployment (us-east-1 + us-west-2)
- ✅ Lambda functions in both regions
- ✅ S3 cross-region replication
- ✅ DynamoDB global table
- ✅ CI/CD IAM user with access keys
- ✅ Custom Lambda configuration (1024MB, 30s timeout)

## Prerequisites

**For Route53 Domain:** Your domain must be in Route53 in the same AWS account.

See [Domain Setup Guide](../../docs/DOMAIN_SETUP.md) for migration instructions.

## Usage

### Option 1: With Route53 Domain (Recommended)

If you have a domain in Route53, enable automatic DNS management:

```bash
terraform init
terraform apply \
  -var="project_name=my-app" \
  -var="domain_name=example.com" \
  -var="subdomain=app" \
  -var="route53_managed=true"
```

### Option 2: With External Domain (not in Route53)

If your domain is with another provider (default for testing):

```bash
terraform init
terraform apply \
  -var="project_name=my-app" \
  -var="domain_name=example.com" \
  -var="subdomain=app"
```

Terraform will output DNS records to add to your domain registrar.

### Option 3: No Custom Domain (CloudFront URL only)

```bash
terraform init
terraform apply \
  -var="project_name=my-app" \
  -var="domain_name=null"
```

## Output

### Route53 Managed
```
application_url = "https://app.example.com"
custom_domain_enabled = true
route53_managed = true
```

### External Domain
```
application_url = "https://app.example.com"
custom_domain_enabled = true
route53_managed = false

dns_validation_records = {
  # Add these to your DNS provider for ACM validation
}

dns_cloudfront_record = {
  # Add this to your DNS provider to point to CloudFront
}
```

## Configuration Options

This example shows all available features. You can customize:

- `lambda_memory_size` - Memory allocation (default: 512MB, example: 1024MB)
- `lambda_timeout` - Execution timeout (default: 10s, example: 30s)
- `enable_dr` - Disable DR to save costs (default: true)
- `create_ci_cd_user` - Disable CI/CD user if not needed (default: true)

## Cost Estimate

Monthly costs for low-traffic production site:
- Lambda: $1-5
- CloudFront: $5-10
- S3: $2-5
- DynamoDB: $1-5
- Route53: $0.50
- **Total: ~$10-25/month**

Scales automatically with traffic.
