output "bedrock_logs_bucket_id" {
  value = aws_s3_bucket.bedrock_logs.id
}

output "bedrock_logs_bucket_arn" {
  value = aws_s3_bucket.bedrock_logs.arn
}

output "bedrock_logs_kms_key_arn" {
  value = var.create_kms_key ? aws_kms_key.bedrock_logs[0].arn : null
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.bedrock.dashboard_name
}
