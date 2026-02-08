# Basic Example

Minimal setup for development and testing - no custom domain required.

## What This Deploys

- ✅ CloudFront distribution (uses CloudFront URL)
- ✅ Single region (us-east-1)
- ✅ Lambda function
- ✅ S3 buckets
- ✅ DynamoDB table
- ❌ No custom domain (uses CloudFront URL)
- ❌ No DR region
- ❌ No CI/CD IAM user

## Usage

```bash
terraform init
terraform apply -var="project_name=my-test-app"
```

## Output

```
application_url = "https://d111111abcdef8.cloudfront.net"
```

## Benefits

- **No prerequisites** - No domain setup required
- **Fast deployment** - Immediate setup
- **Low cost** - No Route53 charges
- **Perfect for testing** - Validate the architecture

## Upgrade Path

To add a custom domain later, see the [complete example](../complete/).
