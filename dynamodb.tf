# DynamoDB Global Table for visit counter and session data
# Using the modern aws_dynamodb_table_replica approach

# Primary region table (us-east-1)
resource "aws_dynamodb_table" "visits_primary" {
  count        = var.enable_dynamo ? 1 : 0
  provider     = aws.primary
  name         = "${local.app_name}-visits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Enable streams for replication (required for Global Tables)
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = local.common_tags

  # Ignore replica changes - managed by aws_dynamodb_table_replica resource
  lifecycle {
    ignore_changes = [replica]
  }
}

# DR region table replica (us-west-2)
# Only created when both DynamoDB and DR are enabled
resource "aws_dynamodb_table_replica" "visits_dr" {
  count            = var.enable_dynamo && var.enable_dr ? 1 : 0
  provider         = aws.dr
  global_table_arn = aws_dynamodb_table.visits_primary[0].arn

  tags = local.common_tags
}

# Initial counter item (only in primary region)
resource "aws_dynamodb_table_item" "counter" {
  count      = var.enable_dynamo ? 1 : 0
  provider   = aws.primary
  table_name = aws_dynamodb_table.visits_primary[0].name
  hash_key   = "PK"
  range_key  = "SK"

  item = jsonencode({
    PK    = { S = "GLOBAL" }
    SK    = { S = "COUNTER" }
    count = { N = "0" }
  })

  depends_on = [aws_dynamodb_table.visits_primary]
}
