# Architecture

Multi-region serverless SSR platform on AWS with automatic failover.

**[📊 View Detailed Diagram](diagram.md)**

## Overview

```
User → CloudFront (Global CDN)
         ├─ Dynamic: Lambda us-east-1 → (failover) → Lambda us-west-2
         └─ Static:  S3 us-east-1    → (failover) → S3 us-west-2
```

CloudFront handles all failover automatically using origin groups. When a primary origin returns 5xx errors, CloudFront routes to DR.

## Core Components

### CloudFront Distribution (Global)
- Global CDN with ~450 edge locations
- Origin groups for automatic failover (Lambda + S3)
- Optional custom domain with ACM SSL certificate
- Handles HTTPS termination and caching

### Lambda Functions (Regional)
- **Runtime**: Node.js 20.x
- **Regions**: Primary (us-east-1) + DR (us-west-2)
- **Default**: 512MB memory, 10s timeout
- **Access**: Lambda Function URLs (public HTTPS endpoints)
- **Bootstrap**: Includes placeholder code, works immediately

### S3 Buckets (Regional)
- **Static Assets**: Public files (JS, CSS, images) with cross-region replication
- **Deployments**: Lambda code packages (primary + DR)
- **Access**: CloudFront via Origin Access Identity (OAI)

### DynamoDB (Global Table)
- On-demand pricing (pay per request)
- Automatic bi-directional replication between regions
- Example schema included (visits counter)

### Route 53 (Optional)
- Only created if `domain_name` is set and `route53_managed = true`
- Simple A record (alias) pointing to CloudFront
- Automatic ACM certificate DNS validation

### IAM Roles
- **Lambda Execution Role**: DynamoDB, S3, CloudWatch Logs access
- **S3 Replication Role**: Cross-region replication
- **CI/CD User** (optional): Deploy permissions for automation

## Traffic Flow

### SSR Requests (Dynamic)
```
User → CloudFront → Lambda (primary or DR) → DynamoDB
```
- **Stale-While-Revalidate (SWR)**: Instant cache hits with background refresh
- Cache duration controlled by Lambda via `Cache-Control` headers
- Typical: 30-300s cache + 2-60 min stale-while-revalidate
- Automatic failover on 5xx errors

See [Caching Guide](CACHING.md) for details on tuning cache strategy.

### Static Assets (/_nuxt/*, /favicon.ico)
```
User → CloudFront → S3 (primary or DR)
```
- Long cache (1 day to 1 year)
- Immutable assets
- Automatic failover on 5xx errors

## Failover

CloudFront origin groups detect 5xx errors and automatically route to DR:
- **Detection**: Immediate (on 500, 502, 503, 504)
- **Failover**: Automatic
- **Recovery**: Automatic when primary is healthy

No health checks needed - CloudFront handles everything.

## Domain Options

### 1. No Domain (CloudFront URL)
```hcl
project_name = "my-app"
# domain_name = null (default)
```
**URL**: `https://d111111abcdef8.cloudfront.net`

### 2. Route53 Domain (Automated)
```hcl
project_name      = "my-app"
domain_name       = "example.com"
subdomain         = "app"
route53_managed   = true
```
**URL**: `https://app.example.com` (automatic DNS + SSL)

### 3. External Domain (Manual DNS)
```hcl
project_name      = "my-app"
domain_name       = "example.com"
subdomain         = "app"
route53_managed   = false
```
**URL**: `https://app.example.com` (after adding DNS records manually)

## DR Options

### With DR (Default)
```hcl
enable_dr = true  # default
```
- Multi-region deployment
- Automatic failover
- Data replication
- Higher availability

### Without DR
```hcl
enable_dr = false
```
- Single region (us-east-1)
- Lower cost (~30% savings)
- Good for dev/test

## Cost Estimate

Low-traffic production site (~10K requests/day):

| Service | Monthly Cost |
|---------|-------------|
| Lambda | $1-5 |
| CloudFront | $5-10 |
| S3 | $1-3 |
| DynamoDB | $1-5 |
| Route 53 | $0.50 (if used) |
| ACM | Free |
| **Total** | **$10-25** |

Scales automatically with traffic. DR adds ~$5-10/month for replication.

## Performance

- **Cold start**: 500-1000ms (first request after idle)
- **Warm Lambda**: 50-200ms response time
- **Cached (SWR)**: 10-50ms (served from CloudFront edge)
- **DynamoDB**: <10ms queries
- **Static assets**: <20ms (from edge)
- **CloudFront cache hit**: 70-95% typical with SWR

### Stale-While-Revalidate Impact

| Scenario | Before SWR | After SWR | Improvement |
|----------|------------|-----------|-------------|
| Repeat page view | 200-500ms | 10-50ms | **10-20x faster** |
| High traffic | Lambda thrashing | Edge cached | **Cost reduction** |
| User experience | Variable latency | Consistently fast | **Better UX** |

## Security

- **Network**: S3 private (OAI only), Lambda public (Function URLs), DynamoDB encrypted
- **SSL/TLS**: ACM certificates (auto-renew), CloudFront enforces HTTPS, TLS 1.2+
- **IAM**: Minimal permissions (least privilege)
- **No VPC**: Faster cold starts, no NAT costs

## Limitations

- Lambda timeout: 10s default (max 15 minutes)
- Lambda memory: 512MB default (max 10GB)
- Response size: 6MB (Lambda Function URL limit)
- Concurrent executions: 1000 default (can increase)

## Monitoring

CloudWatch logs and metrics are automatic:
- Lambda: `/aws/lambda/<function-name>`
- CloudFront: Requests, errors, bytes transferred
- DynamoDB: Read/write capacity, throttles

**Recommended alarms** (not included):
- Lambda error rate > 1%
- CloudFront 5xx rate > 0.5%
- DynamoDB throttled requests

## Related Docs

- **[📊 Detailed Diagram](diagram.md)** - Visual architecture
- **[🚀 Getting Started](GETTING_STARTED.md)** - Step-by-step deployment
- **[📘 API Reference](API.md)** - All variables and outputs
- **[⚡ Caching Guide](CACHING.md)** - Stale-While-Revalidate configuration
- **[🔧 Troubleshooting](TROUBLESHOOTING.md)** - Common issues
