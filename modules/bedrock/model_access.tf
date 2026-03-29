data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    sid    = "BedrockInvokeAllowedModels"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = var.model_invoke_resource_arns
  }

  statement {
    sid    = "BedrockListAndInfo"
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel",
      "bedrock:GetInferenceProfile",
      "bedrock:ListInferenceProfiles",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "bedrock_invoke" {
  name_prefix = "${var.name_prefix}-invoke-"
  description = "Least-privilege invoke access to selected Bedrock foundation models and inference profiles"
  policy      = data.aws_iam_policy_document.bedrock_invoke.json
}
