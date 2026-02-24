# Lambda Functions for SSR - Primary and DR regions

# Bootstrap Lambda Code
# This creates a minimal Lambda package so infrastructure can be created
# without requiring a pre-built application. The real app code is deployed later.
# ------------------------------------------------------------------------------

# Cache header helper - provides Stale-While-Revalidate values per path
# Usage in your app: import { getCacheHeaders } from './utils/cache'
locals {
  # This helper shows how to implement SWR in your application code
  cache_helper_docs = <<-HELPER
/**
 * Get Cache-Control headers for Stale-While-Revalidate pattern
 * 
 * @param {string} path - Request path
 * @returns {object} Cache-Control header value
 * 
 * Examples:
 *   - public, max-age=60, stale-while-revalidate=300
 *     → Cache 60s, serve stale up to 5 min while refreshing in background
 *   
 *   - public, max-age=300, stale-while-revalidate=3600  
 *     → Cache 5 min, serve stale up to 1 hour while refreshing
 *   
 *   - no-store
 *     → Never cache (for private/user-specific pages)
 *   
 *   - public, max-age=0, stale-while-revalidate=86400
 *     → Always serve from cache if available, refresh daily
 */
function getCacheHeaders(path) {
  // API routes - never cache
  if (path.startsWith('/api/')) {
    return { 'Cache-Control': 'no-store' };
  }
  
  // Health check - short cache, quick refresh
  if (path === '/api/health') {
    return { 'Cache-Control': 'public, max-age=5, stale-while-revalidate=30' };
  }
  
  // Homepage - moderate cache with SWR
  if (path === '/') {
    return { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' };
  }
  
  // Static-style pages (blog, docs) - longer cache with SWR  
  if (path.startsWith('/blog/') || path.startsWith('/docs/')) {
    return { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=3600' };
  }
  
  // User-specific pages - no cache
  if (path.startsWith('/profile') || path.startsWith('/dashboard') || path.startsWith('/account')) {
    return { 'Cache-Control': 'no-store' };
  }
  
  // Default - short cache with moderate SWR
  return { 'Cache-Control': 'public, max-age=30, stale-while-revalidate=120' };
}
HELPER

  # Bootstrap Lambda code with SWR support
  bootstrap_code = <<-EOF
// Stale-While-Revalidate cache helper (copy to your app's utils/cache.js)
function getCacheHeaders(path) {
  if (path.startsWith('/api/')) {
    return 'no-store';
  }
  if (path === '/api/health') {
    return 'public, max-age=5, stale-while-revalidate=30';
  }
  if (path === '/') {
    return 'public, max-age=60, stale-while-revalidate=300';
  }
  return 'public, max-age=30, stale-while-revalidate=120';
}

exports.handler = async (event, context) => {
  const path = event.rawPath || event.path || '/';
  
  // Health check endpoint
  if (path === '/api/health') {
    return {
      statusCode: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Cache-Control': getCacheHeaders(path)
      },
      body: JSON.stringify({ 
        status: 'bootstrap', 
        message: 'Lambda initialized - awaiting application deployment',
        swr_enabled: true,
        timestamp: new Date().toISOString()
      })
    };
  }
  
  // Default response for all other paths
  return {
    statusCode: 200,
    headers: { 
      'Content-Type': 'text/html',
      'Cache-Control': getCacheHeaders(path)
    },
    body: `<!DOCTYPE html>
<html>
<head>
  <title>$${var.project_name}</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; max-width: 650px; margin: 50px auto; padding: 20px; line-height: 1.6; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }
    .swr { background: #e8f5e9; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #4caf50; }
    .swr h3 { margin-top: 0; color: #2e7d32; }
    .cache-table { width: 100%; border-collapse: collapse; margin: 15px 0; }
    .cache-table th, .cache-table td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
    .cache-table th { background: #f5f5f5; }
  </style>
</head>
<body>
  <h1>$${var.project_name}</h1>
  <p>Serverless SSR Platform - Bootstrap Mode</p>
  
  <div class="swr">
    <h3>✨ Stale-While-Revalidate Enabled</h3>
    <p>Pages are cached at CloudFront edge locations with automatic background refresh.</p>
    <ul>
      <li><strong>First load:</strong> ~500-1000ms (Lambda cold start + render)</li>
      <li><strong>Cached load:</strong> &lt;50ms (served from edge)</li>
      <li><strong>Background:</strong> Cache refreshes automatically while users get instant responses</li>
    </ul>
  </div>
  
  <p>Infrastructure is ready. Deploy your application to see content.</p>
  
  <h3>Bootstrap Cache Strategy:</h3>
  <table class="cache-table">
    <tr><th>Path</th><th>Cache Policy</th><th>Description</th></tr>
    <tr><td><code>/api/*</code></td><td><code>no-store</code></td><td>Never cache API responses</td></tr>
    <tr><td><code>/api/health</code></td><td>5s + 30s SWR</td><td>Short cache for health checks</td></tr>
    <tr><td><code>/</code> (home)</td><td>60s + 300s SWR</td><td>Homepage cached 1 min, stale up to 5 min</td></tr>
    <tr><td><code>/*</code> (default)</td><td>30s + 120s SWR</td><td>Default: 30s cache, stale up to 2 min</td></tr>
  </table>
  
  <p>Health check: <a href="/api/health">/api/health</a></p>
</body>
</html>`
  };
};
EOF
}

# Create archive from inline code
data "archive_file" "bootstrap" {
  type        = "zip"
  output_path = "${path.module}/bootstrap.zip"

  source {
    content  = local.bootstrap_code
    filename = "index.js"
  }

  # Add package.json to specify CommonJS for Node.js 22 compatibility
  source {
    content = jsonencode({
      type = "commonjs"
    })
    filename = "package.json"
  }
}

# Upload bootstrap code to S3 (Primary)
resource "aws_s3_object" "bootstrap_primary" {
  provider = aws.primary

  bucket = module.storage.lambda_deployments_primary_id
  key    = "lambda/function.zip"
  source = data.archive_file.bootstrap.output_path
  etag   = data.archive_file.bootstrap.output_md5
}

# Upload bootstrap code to S3 (DR) - if enabled
resource "aws_s3_object" "bootstrap_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  bucket = module.storage.lambda_deployments_dr_id
  key    = "lambda/function.zip"
  source = data.archive_file.bootstrap.output_path
  etag   = data.archive_file.bootstrap.output_md5
}

module "lambda_primary" {
  source = "./modules/lambda"

  providers = {
    aws = aws.primary
  }

  function_name         = "${local.app_name}-primary"
  description           = "${var.project_name} - Primary Region (${var.primary_region})"
  create_role           = false
  role_arn              = aws_iam_role.lambda_execution.arn
  handler               = "index.handler"
  runtime               = "nodejs20.x"
  memory_size           = var.lambda_memory_size
  timeout               = var.lambda_timeout
  s3_bucket             = module.storage.lambda_deployments_primary_id
  s3_key                = "lambda/function.zip"
  environment_variables = local.lambda_environment
  tags                  = local.common_tags

  depends_on = [aws_s3_object.bootstrap_primary]
}

module "lambda_dr" {
  count  = var.enable_dr ? 1 : 0
  source = "./modules/lambda"

  providers = {
    aws = aws.dr
  }

  function_name         = "${local.app_name}-dr"
  description           = "${var.project_name} - DR Region (${var.dr_region})"
  create_role           = false
  role_arn              = aws_iam_role.lambda_execution.arn
  handler               = "index.handler"
  runtime               = "nodejs20.x"
  memory_size           = var.lambda_memory_size
  timeout               = var.lambda_timeout
  s3_bucket             = module.storage.lambda_deployments_dr_id
  s3_key                = "lambda/function.zip"
  environment_variables = local.lambda_environment
  tags                  = local.common_tags

  depends_on = [aws_s3_object.bootstrap_dr]
}

# Lambda Environment Variables
# ------------------------------------------------------------------------------

locals {
  lambda_environment = merge(
    {
      NODE_ENV       = "production"
      NITRO_PRESET   = "aws-lambda"
      PRIMARY_REGION = var.primary_region
      DR_REGION      = var.dr_region
      PROJECT_NAME   = var.project_name
      # ORIGIN_SECRET removed in v2.4.1 - AWS_IAM authentication replaces X-Origin-Secret header validation
    },
    var.enable_dynamo ? { DYNAMODB_TABLE = aws_dynamodb_table.visits_primary[0].name } : {}
  )
}

# IAM Role for Lambda Execution
# ------------------------------------------------------------------------------

resource "aws_iam_role" "lambda_execution" {
  provider = aws.primary
  name     = "${local.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# IAM Policy for DynamoDB Access
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_dynamodb" {
  count    = var.enable_dynamo ? 1 : 0
  provider = aws.primary
  name     = "${local.app_name}-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.visits_primary[0].arn,
          "${aws_dynamodb_table.visits_primary[0].arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for S3 Access (Lambda needs to read deployment packages)
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_s3" {
  provider = aws.primary
  name     = "${local.app_name}-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = concat([
          "${module.storage.lambda_deployments_primary_arn}/lambda/*"
        ], var.enable_dr ? ["${module.storage.lambda_deployments_dr_arn}/lambda/*"] : [])
      }
    ]
  })

  tags = local.common_tags
}

# Attach Policies to Lambda Role
# ------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  count      = var.enable_dynamo ? 1 : 0
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_dynamodb[0].arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  provider   = aws.primary
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_s3.arn
}

# Lambda Function URLs
# ------------------------------------------------------------------------------
# Using AWS_IAM authorization with custom origin request policy that excludes
# body headers (Content-Length, Transfer-Encoding) which CloudFront modifies
# after signing, causing signature validation failures.

resource "aws_lambda_function_url" "primary" {
  provider = aws.primary

  function_name      = module.lambda_primary.function_name
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_function_url" "dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  function_name      = module.lambda_dr[0].function_name
  authorization_type = "AWS_IAM"
}

# CloudFront OAC Lambda Permissions
# OAC signing requires both InvokeFunctionUrl AND InvokeFunction actions.
# Scoped by both source_arn (specific distribution) and source_account.

resource "aws_lambda_permission" "cloudfront_primary" {
  provider = aws.primary

  statement_id   = "${var.project_name}-AllowCloudFrontOAC"
  action         = "lambda:InvokeFunctionUrl"
  function_name  = module.lambda_primary.function_name
  principal      = "cloudfront.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "cloudfront_primary_dist" {
  provider = aws.primary

  statement_id  = "${var.project_name}-AllowCloudFrontOACDist"
  action        = "lambda:InvokeFunctionUrl"
  function_name = module.lambda_primary.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.arn
}

resource "aws_lambda_permission" "cloudfront_primary_invoke" {
  provider = aws.primary

  statement_id   = "${var.project_name}-AllowCloudFrontOACInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda_primary.function_name
  principal      = "cloudfront.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "cloudfront_primary_invoke_dist" {
  provider = aws.primary

  statement_id  = "${var.project_name}-AllowCloudFrontOACInvokeDist"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_primary.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.arn
}

resource "aws_lambda_permission" "cloudfront_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  statement_id   = "${var.project_name}-AllowCloudFrontOAC"
  action         = "lambda:InvokeFunctionUrl"
  function_name  = module.lambda_dr[0].function_name
  principal      = "cloudfront.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "cloudfront_dr_dist" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  statement_id  = "${var.project_name}-AllowCloudFrontOACDist"
  action        = "lambda:InvokeFunctionUrl"
  function_name = module.lambda_dr[0].function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.arn
}

resource "aws_lambda_permission" "cloudfront_dr_invoke" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  statement_id   = "${var.project_name}-AllowCloudFrontOACInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda_dr[0].function_name
  principal      = "cloudfront.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "cloudfront_dr_invoke_dist" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  statement_id  = "${var.project_name}-AllowCloudFrontOACInvokeDist"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_dr[0].function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.arn
}
