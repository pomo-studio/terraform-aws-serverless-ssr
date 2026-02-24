terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.dr]
    }
  }
}

resource "aws_s3_bucket" "lambda_deployments_primary" {
  bucket = "${var.app_name}-lambda-deployments-${var.account_id}-${var.primary_region}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_deployments_primary" {
  bucket = aws_s3_bucket.lambda_deployments_primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "lambda_deployments_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  bucket = "${var.app_name}-lambda-deployments-${var.account_id}-${var.dr_region}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_deployments_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.lambda_deployments_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.app_name}-static-${var.account_id}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontOAIAccess"
        Effect = "Allow"
        Principal = {
          CanonicalUser = var.cloudfront_oai_canonical_user_id
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_assets.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.static_assets]
}

resource "aws_s3_bucket" "static_assets_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  bucket = "${var.app_name}-static-${var.account_id}-dr"
  tags   = var.common_tags
}

resource "aws_s3_bucket_versioning" "static_assets_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.static_assets_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.static_assets_dr[0].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "static_assets_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.static_assets_dr[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontOAIAccess"
        Effect = "Allow"
        Principal = {
          CanonicalUser = var.cloudfront_oai_canonical_user_id
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_assets_dr[0].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.static_assets_dr]
}

resource "aws_iam_role" "replication" {
  name = "${var.app_name}-s3-replication-role"

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

  tags = var.common_tags
}

resource "aws_iam_policy" "replication" {
  name = "${var.app_name}-s3-replication-policy"

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
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket_replication_configuration" "static_assets" {
  count  = var.enable_dr ? 1 : 0
  bucket = aws_s3_bucket.static_assets.id
  role   = aws_iam_role.replication.arn

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
