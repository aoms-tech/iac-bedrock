output "bedrock_invoke_policy_arn" {
  value = aws_iam_policy.bedrock_invoke.arn
}

output "bedrock_logging_role_arn" {
  value = aws_iam_role.bedrock_logging.arn
}

output "cloudwatch_log_group_name" {
  value = aws_cloudwatch_log_group.bedrock_invocations.name
}

output "guardrail_id" {
  value = var.enable_guardrail ? aws_bedrock_guardrail.default[0].guardrail_id : null
}
