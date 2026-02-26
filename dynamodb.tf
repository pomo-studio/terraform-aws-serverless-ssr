module "dynamodb" {
  count  = var.enable_dynamo ? 1 : 0
  source = "./modules/dynamodb"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  name      = "${local.app_name}-visits"
  enable_dr = var.enable_dr
  tags      = local.common_tags
}

resource "aws_dynamodb_table_item" "counter" {
  count      = var.enable_dynamo ? 1 : 0
  provider   = aws.primary
  table_name = module.dynamodb[0].table_name_primary
  hash_key   = "PK"
  range_key  = "SK"

  item = jsonencode({
    PK    = { S = "GLOBAL" }
    SK    = { S = "COUNTER" }
    count = { N = "0" }
  })

  depends_on = [module.dynamodb]
}
