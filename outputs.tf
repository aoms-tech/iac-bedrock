output "bedrock_invoke_policy_arn" {
  description = "Attach this policy to roles/users that should invoke allowed models."
  value       = module.bedrock.bedrock_invoke_policy_arn
}

output "bedrock_logging_role_arn" {
  description = "IAM role Bedrock assumes to write invocation logs to CloudWatch."
  value       = module.bedrock.bedrock_logging_role_arn
}

output "bedrock_logs_bucket_name" {
  value = module.observability.bedrock_logs_bucket_id
}

output "bedrock_logs_bucket_arn" {
  value = module.observability.bedrock_logs_bucket_arn
}

output "bedrock_logs_kms_key_arn" {
  value = module.observability.bedrock_logs_kms_key_arn
}

output "cloudwatch_log_group_name" {
  value = module.bedrock.cloudwatch_log_group_name
}

output "team_role_arns" {
  description = "Per-team IAM roles with Bedrock invoke policy attached."
  value       = module.iam.team_role_arns
}

output "guardrail_id" {
  description = "Guardrail ID when enable_guardrail is true."
  value       = module.bedrock.guardrail_id
}

output "vpc_endpoint_ids" {
  description = "Interface endpoint IDs when PrivateLink is enabled."
  value       = try(module.networking[0].vpc_endpoint_ids, {})
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name for Bedrock observability (cost trend, usage by model, usage by user)."
  value       = module.observability.dashboard_name
}
