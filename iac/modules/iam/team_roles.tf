data "aws_caller_identity" "current" {}

locals {
  root_principal   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  trust_principals = var.allow_account_root_trust ? concat(var.team_role_trust_principals, [local.root_principal]) : var.team_role_trust_principals
}

data "aws_iam_policy_document" "team_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "AWS"
      identifiers = local.trust_principals
    }
  }
}

resource "aws_iam_role" "team_bedrock" {
  for_each = var.teams

  name                 = "${var.name_prefix}-${each.value.role_name}"
  assume_role_policy   = data.aws_iam_policy_document.team_assume.json
  max_session_duration = 43200
}

resource "aws_iam_role_policy_attachment" "team_bedrock_invoke" {
  for_each = var.teams

  role       = aws_iam_role.team_bedrock[each.key].name
  policy_arn = var.bedrock_invoke_policy_arn
}
