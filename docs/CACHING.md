# Caching with Stale-While-Revalidate (SWR)

This module implements the **Stale-While-Revalidate** pattern for optimal page load performance.

## What is Stale-While-Revalidate?

SWR is a caching strategy that gives you the best of both worlds:
- ⚡ **Instant page loads** from CloudFront edge cache
- 🔄 **Fresh content** via background revalidation
- 🌍 **Global performance** with ~450 edge locations

### How It Works

```
User Request ──┬─► CloudFront has fresh cache? ──YES──► Return cached page (instant!)
               │                                    │
               │                                    └──► Trigger background refresh
               │
               └─► CloudFront has stale cache? ──YES──► Return stale page (instant!)
                                                    │
                                                    └──► Trigger background refresh
                                                    
               └─► No cache? ──► Invoke Lambda ──► Render & cache ──► Return page
```

### Cache-Control Header Syntax

```
Cache-Control: public, max-age=<fresh>, stale-while-revalidate=<stale>
```

| Directive | Meaning |
|-----------|---------|
| `max-age=60` | Cache is "fresh" for 60 seconds |
| `stale-while-revalidate=300` | Serve stale cache up to 5 min while refreshing |
| `no-store` | Never cache (for private data) |

## Default Cache Strategy

The bootstrap Lambda includes a smart cache strategy out of the box:

| Path Pattern | Cache Policy | Use Case |
|--------------|--------------|----------|
| `/api/*` | `no-store` | API responses (never cache) |
| `/api/health` | 5s + 30s SWR | Health checks (short cache) |
| `/` (homepage) | 60s + 300s SWR | Homepage (balance of fresh/fast) |
| `/blog/*`, `/docs/*` | 300s + 3600s SWR | Content pages (longer cache OK) |
| `/profile`, `/dashboard` | `no-store` | User-specific pages (private) |
| `/*` (default) | 30s + 120s SWR | All other pages |

## Implementation in Your App

### 1. Copy the Cache Helper

Create `utils/cache.js` in your Nuxt.js app:

```javascript
/**
 * Get Cache-Control headers for Stale-While-Revalidate pattern
 * 
 * @param {string} path - Request path
 * @returns {object} Cache-Control header value
 */
export function getCacheHeaders(path) {
  // API routes - never cache
  if (path.startsWith('/api/')) {
    return { 'Cache-Control': 'no-store' };
  }
  
  // Health check - short cache
  if (path === '/api/health') {
    return { 'Cache-Control': 'public, max-age=5, stale-while-revalidate=30' };
  }
  
  // Homepage - moderate cache
  if (path === '/') {
    return { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' };
  }
  
  // Blog posts - longer cache (content changes infrequently)
  if (path.startsWith('/blog/')) {
    return { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=3600' };
  }
  
  // Product pages - medium cache
  if (path.startsWith('/products/')) {
    return { 'Cache-Control': 'public, max-age=120, stale-while-revalidate=600' };
  }
  
  // User pages - never cache (private)
  if (path.startsWith('/profile') || path.startsWith('/dashboard')) {
    return { 'Cache-Control': 'no-store' };
  }
  
  // Default - short cache
  return { 'Cache-Control': 'public, max-age=30, stale-while-revalidate=120' };
}
```

### 2. Use in Your Nitro/Nuxt Handler

```typescript
// server/routes/[...slug].ts
import { getCacheHeaders } from '~/utils/cache';

export default defineEventHandler(async (event) => {
  const path = getRequestURL(event).pathname;
  
  // Set cache headers for CloudFront
  const cacheHeaders = getCacheHeaders(path);
  setResponseHeaders(event, cacheHeaders);
  
  // Your SSR logic here
  const pageData = await fetchPageData(path);
  
  return {
    // ... page data
  };
});
```

### 3. Or Use Nitro Route Rules

In `nuxt.config.ts`:

```typescript
export default defineNuxtConfig({
  nitro: {
    routeRules: {
      // Homepage: 1 min fresh, 5 min stale
      '/': { headers: { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' } },
      
      // Blog: 5 min fresh, 1 hour stale
      '/blog/**': { headers: { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=3600' } },
      
      // API: never cache
      '/api/**': { headers: { 'Cache-Control': 'no-store' } },
      
      // User pages: never cache
      '/profile/**': { headers: { 'Cache-Control': 'no-store' } },
      '/dashboard/**': { headers: { 'Cache-Control': 'no-store' } },
    }
  }
});
```

## Tuning Your Cache Strategy

### Content Freshness vs Performance

| Cache Duration | Best For | Trade-off |
|----------------|----------|-----------|
| `no-store` | User data, shopping carts | Slowest (always hits Lambda) |
| `max-age=30` | Frequently changing content | Fast, but more Lambda invocations |
| `max-age=60` | Homepages, landing pages | Good balance |
| `max-age=300` | Blog posts, documentation | Faster, slightly stale risk |
| `max-age=0, stale-while-revalidate=86400` | Rarely changing content | Fastest, daily refresh |

### SWR Duration Guidelines

- **Short SWR (30-120s)**: Good for semi-dynamic content
- **Medium SWR (300-600s)**: Good for most marketing pages  
- **Long SWR (3600s+)**: Good for blog posts, documentation

### Per-Route Overrides

For specific pages, override in your page component:

```vue
<script setup>
// pages/blog/[slug].vue
const route = useRoute();

// Set custom cache headers for this page type
if (import.meta.server) {
  const event = useRequestEvent();
  setResponseHeaders(event, {
    'Cache-Control': 'public, max-age=600, stale-while-revalidate=7200'
  });
}
</script>
```

## How to Verify It's Working

### 1. Check Response Headers

```bash
# First request (should hit Lambda)
curl -I https://your-domain.com/
# Look for: x-cache: Miss from cloudfront

# Second request (should hit cache)
curl -I https://your-domain.com/
# Look for: x-cache: Hit from cloudfront
```

### 2. Check CloudFront Console

1. Go to CloudFront Console → Your Distribution
2. Click "Monitoring" tab
3. Look for **Cache Hit Rate** (target: 80%+)

### 3. Check Browser DevTools

1. Open DevTools → Network tab
2. Load your page
3. Check response headers for `Cache-Control`
4. Check timing - cached responses should be <100ms

## Common Patterns

### E-commerce Site

```javascript
function getCacheHeaders(path) {
  // Product listings - cache briefly
  if (path === '/products') {
    return { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' };
  }
  
  // Individual products - cache longer (price changes are rare)
  if (path.match(/^\/products\/[^\/]+$/)) {
    return { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=1800' };
  }
  
  // Cart, checkout - never cache
  if (path.startsWith('/cart') || path.startsWith('/checkout')) {
    return { 'Cache-Control': 'no-store' };
  }
  
  // Homepage - cache moderately
  return { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' };
}
```

### SaaS Dashboard

```javascript
function getCacheHeaders(path) {
  // Marketing pages - cache aggressively
  if (['/pricing', '/features', '/about'].includes(path)) {
    return { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=3600' };
  }
  
  // Documentation - cache very aggressively
  if (path.startsWith('/docs/')) {
    return { 'Cache-Control': 'public, max-age=600, stale-while-revalidate=86400' };
  }
  
  // Blog posts - cache aggressively
  if (path.startsWith('/blog/')) {
    return { 'Cache-Control': 'public, max-age=600, stale-while-revalidate=86400' };
  }
  
  // All app pages - never cache (user-specific)
  if (path.startsWith('/app/')) {
    return { 'Cache-Control': 'no-store' };
  }
  
  return { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' };
}
```

## Troubleshooting

### Cache Not Working

1. **Check headers**: Ensure your Lambda returns `Cache-Control` header
2. **Check policy**: Verify CloudFront cache policy honors origin headers
3. **Check methods**: Only GET/HEAD requests are cached

### Too Much Stale Content

- Reduce `max-age` for fresher initial cache
- Reduce `stale-while-revalidate` to limit stale window
- Use cache invalidation for urgent updates

### High Lambda Invocation Count

- Increase `max-age` to reduce origin hits
- Increase `stale-while-revalidate` to allow more stale serving
- Use longer cache for static content

### Cache Hit Rate Too Low

- Check if query strings or cookies are varying (creates unique cache keys)
- Ensure `Cache-Control` headers are being sent correctly
- Consider CloudFront cache key customization if needed

## Performance Expectations

| Scenario | Response Time | Lambda Invoked? |
|----------|---------------|-----------------|
| Cold cache + cold Lambda | 1000-2000ms | Yes |
| Cold cache + warm Lambda | 200-500ms | Yes |
| Warm cache (fresh) | 10-50ms | No |
| Warm cache (stale) | 10-50ms | Yes (background) |

**Typical cache hit rates**: 70-95% depending on traffic patterns and cache TTLs.

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Getting Started](GETTING_STARTED.md)
- [Troubleshooting](TROUBLESHOOTING.md)
