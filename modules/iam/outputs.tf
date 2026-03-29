output "team_role_arns" {
  value = { for k, r in aws_iam_role.team_bedrock : k => r.arn }
}
