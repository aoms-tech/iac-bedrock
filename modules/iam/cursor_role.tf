# Cross-account role for Cursor to assume (prod only) and invoke Bedrock via the shared invoke policy.

data "aws_iam_policy_document" "cursor_bedrock_assume" {
  count = var.enable_cursor_bedrock_cross_account_role ? 1 : 0

  statement {
    sid    = "AllowCursorCrossAccountAssume"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "AWS"
      identifiers = [var.cursor_cross_account_assumer_role_arn]
    }

    dynamic "condition" {
      for_each = length(trimspace(var.cursor_bedrock_external_id)) > 0 ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [trimspace(var.cursor_bedrock_external_id)]
      }
    }
  }
}

resource "aws_iam_role" "cursor_bedrock" {
  count = var.enable_cursor_bedrock_cross_account_role ? 1 : 0

  name                 = "${var.name_prefix}-${var.cursor_bedrock_role_name_suffix}"
  assume_role_policy   = data.aws_iam_policy_document.cursor_bedrock_assume[0].json
  max_session_duration = 43200
}

resource "aws_iam_role_policy_attachment" "cursor_bedrock_invoke" {
  count = var.enable_cursor_bedrock_cross_account_role ? 1 : 0

  role       = aws_iam_role.cursor_bedrock[0].name
  policy_arn = var.bedrock_invoke_policy_arn
}
