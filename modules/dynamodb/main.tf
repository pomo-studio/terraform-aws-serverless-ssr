resource "aws_dynamodb_table" "primary" {
  provider = aws.primary

  name         = var.name
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

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  lifecycle {
    ignore_changes = [replica]
  }

  tags = var.tags
}

resource "aws_dynamodb_table_replica" "dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr

  global_table_arn = aws_dynamodb_table.primary.arn
  tags             = var.tags
}
