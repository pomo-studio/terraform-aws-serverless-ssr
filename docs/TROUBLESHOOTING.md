# Troubleshooting Guide

Common issues and solutions when deploying with the Serverless SSR Module.

---

## Infrastructure Deployment Issues

### Error: "ResourceNotFoundException: The specified log group does not exist"

**When:** After deployment, checking Lambda logs

**Cause:** Lambda hasn't been invoked yet, so CloudWatch log group wasn't created

**Solution:** This is normal. Invoke the Lambda or wait for first request:
```bash
aws lambda invoke --function-name <function-name> --region <region> /tmp/response.json
```

---

### Error: "Invalid fully qualified domain name" (Route53 Health Check)

**Full error:**
```
Error: creating Route53 Health Check: operation error Route 53: CreateHealthCheck,
https response error StatusCode: 400, RequestID: ..., InvalidInput:
Invalid fully qualified domain name: It may not contain reserved characters of RFC1738 ";/?:@=&"
```

**Cause:** Bug in versions before v1.0.1 - Lambda Function URLs end with "/" which is invalid for health checks

**Solution:**
```bash
# Update to latest version
terraform init -upgrade

# Or manually fix route53.tf if using older version
```

**Fixed in:** Commit `adfe11a` (2026-02-07)

---

### Error: "Provider configuration not present" during validation

**Full error:**
```
Error: Provider configuration not present
To work with aws_lambda_function.primary its original provider configuration at
provider["registry.terraform.io/hashicorp/aws"].primary is required
```

**Cause:** Trying to validate root module standalone (it requires provider aliases)

**Solution:** This is expected for modules with `configuration_aliases`. Validate examples instead:
```bash
cd examples/basic
terraform init
terraform validate
```

---

### Terraform plan takes forever / hangs

**Symptom:** `terraform plan` or `terraform apply` seems stuck

**Common causes:**
1. **DynamoDB global table replication** - Can take 10-15 minutes (normal)
2. **ACM certificate validation** - Can take 5-10 minutes (normal)
3. **AWS credentials expired** - Check `aws sts get-caller-identity`

**Solution:** Be patient for long-running resources. Monitor progress:
```bash
# In another terminal, check AWS console or:
aws dynamodb describe-table --table-name <table-name> --region <region>
```

---

##Application Deployment Issues

### Error: "zip: command not found"

**When:** Running `./scripts/deploy.sh`

**Cause:** `zip` utility not installed

**Solution:**
```bash
# Ubuntu/Debian
sudo apt install zip

# macOS
brew install zip

# Fedora/RHEL
sudo dnf install zip
```

**Fixed in:** Deploy script now checks dependencies upfront (v1.1.0+)

---

### Error: "Function not found: arn:aws:lambda:us-east-2:..."

**Full error:**
```
An error occurred (ResourceNotFoundException) when calling the UpdateFunctionCode operation:
Function not found: arn:aws:lambda:us-east-2:137064409667:function:my-app-primary
```

**Cause:** AWS CLI using default region (us-east-2) instead of your deployment region (us-east-1)

**Solution:**
```bash
# Option 1: Set AWS_REGION environment variable
export AWS_REGION=us-east-1
./scripts/deploy.sh

# Option 2: Update AWS CLI config
aws configure set region us-east-1

# Option 3: Use latest deploy script (v1.1.0+) which specifies region explicitly
```

**Fixed in:** Deploy script v1.1.0+ (commit `49f52a7`)

---

### Error: "Access Denied" when uploading to S3

**When:** Deploy script uploading Lambda package or static assets

**Cause:** AWS credentials don't have S3 write permissions

**Solution:**
```bash
# Verify credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-bucket-name/

# If using IAM user, ensure policy includes:
# - s3:PutObject
# - s3:PutObjectAcl
# - lambda:UpdateFunctionCode
```

---

### Site shows 502 Bad Gateway after deployment

**Symptom:** CloudFront returns 502, Lambda logs show errors

**Common causes:**

**1. Lambda runtime error**
```bash
# Check logs
aws logs tail /aws/lambda/<function-name> --region <region> --since 10m
```

**2. Lambda timeout (default 10s)**
```bash
# Increase timeout in module
lambda_timeout = 30  # seconds
terraform apply
```

**3. DynamoDB permissions missing**
- Check Lambda execution role has `dynamodb:*` permissions on your table

**4. Environment variables misconfigured**
```bash
# Check Lambda environment
aws lambda get-function-configuration \
  --function-name <function-name> \
  --region <region> \
  --query 'Environment'
```

---

### Site shows old/cached content after deployment

**Symptom:** Code deployed but site shows old version

**Cause:** CloudFront cache not invalidated

**Solution:**
```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"

# Wait 1-2 minutes, then test
curl -I https://yourdomain.com
```

**Tip:** Deploy script does this automatically, but you can run manually if needed.

---

## DNS / Domain Issues

### Domain not resolving after deployment

**Symptom:** `dig yourdomain.com` returns NXDOMAIN or old IPs

**Diagnosis:**
```bash
# Check Route 53 records exist
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Check nameservers
dig yourdomain.com NS +short

# Test from Google DNS (often updates faster)
dig @8.8.8.8 yourdomain.com A +short
```

**Solutions:**
1. **Nameservers not updated:** Update at your registrar
2. **DNS propagation:** Wait 10-60 minutes
3. **Records missing:** Add A record pointing to CloudFront
4. **DNSSEC issues:** Disable DNSSEC at registrar

See: [Domain Setup Guide](DOMAIN_SETUP.md#troubleshooting)

---

### SSL certificate pending validation

**Symptom:** `terraform apply` stuck on `aws_acm_certificate_validation`

**Cause:** ACM waiting for DNS validation records

**Diagnosis:**
```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1

# Check if validation CNAME exists in Route 53
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

**Solutions:**
1. **Wait:** Can take 5-30 minutes
2. **Check DNS:** Validation CNAME must exist in Route 53
3. **Manual validation:** Add CNAME if Terraform didn't create it

---

## Configuration Issues

### Error: "No value for required variable"

**Full error:**
```
Error: No value for required variable
on variables.tf line 1:
  1: variable "project_name" {
```

**Cause:** Required variable not provided

**Solution:** Create `terraform.tfvars`:
```hcl
project_name = "my-app"
domain_name  = "example.com"
subdomain    = "app"
```

Or pass via command line:
```bash
terraform apply \
  -var="project_name=my-app" \
  -var="domain_name=example.com" \
  -var="subdomain=app"
```

---

### Config file shows "null" values

**Symptom:** Deploy script output shows `Deploying null`

**Cause:** Config file format incorrect

**Diagnosis:**
```bash
cat config/infra-outputs.json | jq '.app_config.value.project_name'
# Should output: "my-app"
# If outputs: null, format is wrong
```

**Solution:** Export config correctly:
```bash
# CORRECT (from infrastructure directory):
terraform output -json > ~/my-app/config/infra-outputs.json

# WRONG (don't do this):
terraform output -json app_config > config/infra-outputs.json
```

---

## Performance Issues

### Cold start takes 5+ seconds

**Symptom:** First request after idle period is slow

**Cause:** Lambda cold start - normal behavior

**Solutions:**
1. **Increase memory:** More memory = faster cold starts
   ```hcl
   lambda_memory_size = 1024  # default 512
   ```

2. **Provisioned concurrency:** Keep Lambda warm (costs more)
   ```hcl
   # Not included in module - add manually if needed
   ```

3. **Accept it:** Cold starts are part of serverless trade-off

**Typical times:**
- Cold start: 500ms - 2s
- Warm request: 50-200ms

---

### High CloudFront costs

**Symptom:** AWS bill higher than expected

**Common causes:**
1. **No cache:** Requests hitting Lambda instead of edge
2. **Wrong cache policy:** Static assets not cached
3. **High invalidation count:** Charged per invalidation

**Solutions:**
```bash
# Check cache hit ratio
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=<dist-id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average

# Target: >80% cache hit ratio
```

**Optimizations:**
- Use selective invalidation: `/_nuxt/*` instead of `/*`
- Increase TTL for static assets
- Use query string caching properly

---

## Debugging Tools

### Check Lambda logs

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/<function-name> --follow --region <region>

# Last 10 minutes
aws logs tail /aws/lambda/<function-name> --since 10m --region <region>

# Search for errors
aws logs tail /aws/lambda/<function-name> --since 1h --filter-pattern "ERROR" --region <region>
```

### Test Lambda directly

```bash
# Invoke Lambda function
aws lambda invoke \
  --function-name <function-name> \
  --region <region> \
  /tmp/response.json

# View response
cat /tmp/response.json | jq
```

### Test CloudFront

```bash
# Check what CloudFront is serving
curl -I https://yourdomain.com

# Look for headers:
# x-cache: Hit from cloudfront (good - cached)
# x-cache: Miss from cloudfront (not cached - hitting origin)
```

### Check DynamoDB

```bash
# Scan table
aws dynamodb scan \
  --table-name <table-name> \
  --region <region>

# Check table status
aws dynamodb describe-table \
  --table-name <table-name> \
  --region <region>
```

---

## Getting Help

If you're still stuck:

1. **Check AWS Console:** Often shows more detailed errors
2. **Enable debug logging:**
   ```bash
   export TF_LOG=DEBUG
   terraform apply
   ```

3. **Search issues:** [GitHub Issues](https://github.com/apitanga/serverless-ssr-module/issues)

4. **Open an issue:** Include:
   - Terraform version
   - AWS region
   - Error messages
   - Relevant logs
   - `terraform plan` output

---

## Prevention Checklist

Avoid common issues by checking these before deploying:

- [ ] Domain in Route 53 (or migration planned)
- [ ] AWS CLI configured with correct region
- [ ] Required dependencies installed (terraform, aws-cli, jq, zip)
- [ ] IAM permissions sufficient (AdministratorAccess or equivalent)
- [ ] `terraform.tfvars` configured with your values
- [ ] No DNSSEC conflicts (disabled if migrating)
- [ ] CloudWatch logs enabled (default in module)

---

## Known Limitations

- **Lambda timeout:** Max 15 minutes (AWS limit)
- **Response size:** Max 6MB for Lambda Function URLs
- **Certificate region:** ACM cert for CloudFront must be in us-east-1
- **Nameserver TTL:** DNS changes can take up to 48 hours to fully propagate

---

**Last updated:** 2026-02-07
