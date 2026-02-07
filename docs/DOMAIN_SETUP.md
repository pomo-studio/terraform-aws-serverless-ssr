# Domain Setup Guide

This module requires your domain to be managed by AWS Route 53. This guide walks you through the setup process.

## Prerequisites

- A registered domain name
- AWS CLI configured with appropriate credentials
- Domain registrar account access (if migrating)

---

## Option 1: Domain Already in Route 53

If your domain is already in Route 53, you're all set! Skip to [deploying the module](GETTING_STARTED.md).

**Verify:**
```bash
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table
```

If you see your domain listed, proceed with deployment.

---

## Option 2: Migrate Existing Domain to Route 53

### Step 1: Create Route 53 Hosted Zone

```bash
aws route53 create-hosted-zone \
  --name yourdomain.com \
  --caller-reference "migration-$(date +%s)" \
  --hosted-zone-config Comment="Primary hosted zone for yourdomain.com"
```

**Save the nameservers** from the output - you'll need them in Step 3.

### Step 2: Import Existing DNS Records

Before changing nameservers, copy all existing DNS records to Route 53 to avoid downtime.

**Check current DNS records:**
```bash
# A records
dig yourdomain.com A +short

# AAAA records (IPv6)
dig yourdomain.com AAAA +short

# MX records (email)
dig yourdomain.com MX +short

# TXT records (verification, SPF, DKIM)
dig yourdomain.com TXT +short

# CNAME records for subdomains
dig subdomain.yourdomain.com CNAME +short
```

**Import records to Route 53:**

Create a file `dns-records.json`:
```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "yourdomain.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "1.2.3.4"}
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "yourdomain.com",
        "Type": "TXT",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "\"your-verification-string\""}
        ]
      }
    }
  ]
}
```

Apply the records:
```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id /hostedzone/YOUR_ZONE_ID \
  --change-batch file://dns-records.json
```

**Important records to migrate:**
- ✅ A/AAAA records (website IPs)
- ✅ MX records (email)
- ✅ TXT records (SPF, DKIM, domain verification)
- ✅ CNAME records (subdomains, CDNs)

### Step 3: Update Nameservers at Your Registrar

Update your domain's nameservers to point to AWS Route 53.

**AWS Route 53 nameservers** (from Step 1 output):
```
ns-####.awsdns-##.com
ns-####.awsdns-##.net
ns-####.awsdns-##.org
ns-####.awsdns-##.co.uk
```

#### Common Registrars:

**Google Domains / Squarespace:**
1. Go to domains.squarespace.com
2. Select your domain
3. DNS Settings → Nameservers
4. Choose "Custom nameservers"
5. Enter all 4 AWS nameservers
6. Save changes

**GoDaddy:**
1. Go to your domain settings
2. DNS Management → Nameservers
3. Change to "Custom"
4. Enter AWS nameservers
5. Save

**Namecheap:**
1. Domain List → Manage
2. Nameservers → Custom DNS
3. Enter AWS nameservers
4. Save

**Cloudflare:**
1. Remove domain from Cloudflare first
2. Go to your registrar
3. Update nameservers to AWS

### Step 4: Wait for DNS Propagation

DNS changes can take 5-60 minutes (occasionally up to 48 hours).

**Check propagation:**
```bash
# Check if new nameservers are visible
dig yourdomain.com NS +short

# Check from Google DNS (often updates faster)
dig @8.8.8.8 yourdomain.com NS +short

# Should show AWS nameservers:
# ns-####.awsdns-##.com
# ns-####.awsdns-##.net
# ...
```

**Test DNS resolution:**
```bash
# Verify A records work
dig yourdomain.com A +short

# Test from different resolvers
dig @8.8.8.8 yourdomain.com A +short  # Google DNS
dig @1.1.1.1 yourdomain.com A +short  # Cloudflare DNS
```

### Step 5: Disable DNSSEC (if enabled)

If your domain has DNSSEC enabled, you must disable it when changing nameservers.

**Why:** DNSSEC cryptographically signs DNS records. When you change nameservers, the old signatures become invalid, breaking DNS resolution.

**Where to disable:**
- Most registrars: Domain settings → DNSSEC → Disable
- Can re-enable later in Route 53 if needed (advanced)

**Note:** For testing/development, DNSSEC is optional and adds complexity.

---

## Option 3: Register New Domain in Route 53

Register a domain directly through AWS Route 53 Domains:

```bash
# Check if domain is available
aws route53domains check-domain-availability \
  --domain-name myapp.dev

# Register domain (example - adjust parameters)
aws route53domains register-domain \
  --domain-name myapp.dev \
  --duration-in-years 1 \
  --admin-contact file://contact.json \
  --registrant-contact file://contact.json \
  --tech-contact file://contact.json \
  --privacy-protect-admin-contact \
  --privacy-protect-registrant-contact \
  --privacy-protect-tech-contact
```

**Benefits:**
- DNS automatically configured in Route 53
- No nameserver migration needed
- Consolidated billing

**Popular TLD prices:**
- `.dev`: ~$12/year
- `.com`: ~$13/year
- `.click`: ~$3/year
- `.link`: ~$5/year

---

## Verification Checklist

Before deploying the module, verify:

- [ ] Route 53 hosted zone exists
- [ ] All critical DNS records imported
- [ ] Nameservers updated at registrar
- [ ] DNS propagation complete (test with `dig`)
- [ ] DNSSEC disabled (if was enabled)
- [ ] Website/email still working (if migrating)

**Test DNS:**
```bash
# Should return AWS nameservers
dig yourdomain.com NS +short

# Should resolve correctly
dig yourdomain.com A +short
```

---

## Troubleshooting

### Nameservers not updating

**Problem:** `dig yourdomain.com NS` still shows old nameservers after 30+ minutes

**Solutions:**
1. Check you saved changes at registrar
2. Some registrars have a "pending" status - approve changes
3. Clear your local DNS cache: `sudo systemd-resolve --flush-caches` (Linux) or `sudo dscacheutil -flushcache` (Mac)
4. Wait longer - can take up to 48 hours in rare cases

### Website shows old content after migration

**Problem:** Site works but shows outdated content

**Cause:** Local DNS cache or TTL not expired

**Solution:**
1. Wait for previous TTL to expire (check old records' TTL)
2. Test from different network/device
3. Use `dig @8.8.8.8 yourdomain.com A` to bypass local cache

### Email stopped working after migration

**Problem:** Email bouncing after nameserver change

**Cause:** MX records not migrated to Route 53

**Solution:**
1. Check current MX records: `dig yourdomain.com MX +short`
2. Add MX records to Route 53 if missing
3. Wait 5-10 minutes for propagation

### DNSSEC validation errors

**Problem:** Domain not resolving, DNSSEC errors in logs

**Cause:** DNSSEC still enabled with old signatures

**Solution:**
1. Disable DNSSEC at your registrar immediately
2. Wait 1-2 hours for cache to clear
3. Can re-enable in Route 53 later if needed

---

## Cost

**Route 53 Hosted Zone:** $0.50/month per domain

**DNS Queries:** $0.40 per million queries (first 1 billion/month)
- Typical small site: <$1/month in query costs

**Domain Registration** (if using Route 53 Domains): Varies by TLD
- .com: ~$13/year
- .dev: ~$12/year

**Total typical cost:** ~$6-7/month for hosting + domain

---

## Next Steps

Once your domain is in Route 53:

1. ✅ **Verify hosted zone**: `aws route53 list-hosted-zones`
2. ✅ **Test DNS resolution**: `dig yourdomain.com A +short`
3. ➡️ **Deploy infrastructure**: [Getting Started Guide](GETTING_STARTED.md)

---

## Additional Resources

- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [DNS Propagation Checker](https://www.whatsmydns.net/)
- [Route 53 Pricing](https://aws.amazon.com/route53/pricing/)
