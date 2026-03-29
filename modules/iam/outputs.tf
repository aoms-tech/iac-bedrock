output "team_role_arns" {
  value = { for k, r in aws_iam_role.team_bedrock : k => r.arn }
}

output "cursor_bedrock_role_arn" {
  description = "ARN of the cross-account Cursor Bedrock role when enable_cursor_bedrock_cross_account_role is true."
  value       = var.enable_cursor_bedrock_cross_account_role ? aws_iam_role.cursor_bedrock[0].arn : null
}
