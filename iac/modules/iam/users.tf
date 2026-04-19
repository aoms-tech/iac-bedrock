# IAM users managed by Terraform.
# Access keys are created outside Terraform (secrets cannot be re-read after creation);
# use aws iam create-access-key and store the secret in a secrets manager.

resource "aws_iam_user" "users" {
  for_each = var.iam_users

  name = each.key
  tags = each.value.tags
}

resource "aws_iam_user_policy_attachment" "bedrock_invoke" {
  for_each = { for k, v in var.iam_users : k => v if v.attach_bedrock_invoke }

  user       = aws_iam_user.users[each.key].name
  policy_arn = var.bedrock_invoke_policy_arn
}

# Flattened map of user+policy pairs for extra (non-bedrock) policy attachments.
locals {
  user_extra_policy_pairs = {
    for pair in flatten([
      for user, cfg in var.iam_users : [
        for arn in cfg.extra_policy_arns : {
          key        = "${user}:${arn}"
          user       = user
          policy_arn = arn
        }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_iam_user_policy_attachment" "extra" {
  for_each = local.user_extra_policy_pairs

  user       = aws_iam_user.users[each.value.user].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_user_policy_attachment" "litellm_s3" {
  # Gate with a plan-time bool, not litellm_s3_policy_arn == null (ARN is unknown until apply).
  for_each = var.litellm_s3_attachments_enabled ? {
    for k, v in var.iam_users : k => v
    if try(v.attach_litellm_s3, false)
  } : {}

  user       = aws_iam_user.users[each.key].name
  policy_arn = var.litellm_s3_policy_arn
}
