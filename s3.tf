# S3 Buckets for Lambda deployments and static assets

# Primary region - Lambda deployment bucket
resource "aws_s3_bucket" "lambda_deployments_primary" {
  provider = aws.primary
  bucket   = "${local.app_name}-lambda-deployments-${data.aws_caller_identity.current.account_id}-${var.primary_region}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_deployments_primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.lambda_deployments_primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# DR region - Lambda deployment bucket
resource "aws_s3_bucket" "lambda_deployments_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = "${local.app_name}-lambda-deployments-${data.aws_caller_identity.current.account_id}-${var.dr_region}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_deployments_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.lambda_deployments_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Static assets bucket (primary)
resource "aws_s3_bucket" "static_assets" {
  provider = aws.primary
  bucket   = "${local.app_name}-static-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  provider = aws.primary
  bucket   = aws_s3_bucket.static_assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_versioning" "static_assets" {
  provider = aws.primary
  bucket   = aws_s3_bucket.static_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "static_assets" {
  provider = aws.primary
  bucket   = aws_s3_bucket.static_assets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontOAIAccess"
        Effect = "Allow"
        Principal = {
          CanonicalUser = aws_cloudfront_origin_access_identity.main.s3_canonical_user_id
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_assets.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.static_assets]
}

# Cross-Region Replication for static assets (only if DR is enabled)
resource "aws_s3_bucket_replication_configuration" "static_assets" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.static_assets.id
  role     = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    destination {
      bucket = aws_s3_bucket.static_assets_dr[0].arn
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.static_assets,
    aws_s3_bucket_versioning.static_assets_dr
  ]
}

# DR region - Static assets bucket
resource "aws_s3_bucket" "static_assets_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = "${local.app_name}-static-${data.aws_caller_identity.current.account_id}-dr"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "static_assets_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.static_assets_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# IAM Role for S3 replication
resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "${local.app_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "replication" {
  provider = aws.primary
  name     = "${local.app_name}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.static_assets.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.static_assets.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = var.enable_dr ? "${aws_s3_bucket.static_assets_dr[0].arn}/*" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  provider   = aws.primary
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}
