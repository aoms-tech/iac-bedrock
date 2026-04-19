output "config_bucket_id" {
  description = "S3 bucket name for LiteLLM config (e.g. LITELLM_CONFIG_BUCKET_NAME on Railway)."
  value       = aws_s3_bucket.litellm_config.id
}

output "config_bucket_arn" {
  description = "S3 bucket ARN for LiteLLM config."
  value       = aws_s3_bucket.litellm_config.arn
}

output "config_bucket_policy_arn" {
  description = "IAM policy ARN to attach to the IAM user used by LiteLLM for S3 config access."
  value       = aws_iam_policy.litellm_config_s3.arn
}
