output "table_name_primary" {
  value = aws_dynamodb_table.primary.name
}

output "table_arn_primary" {
  value = aws_dynamodb_table.primary.arn
}
