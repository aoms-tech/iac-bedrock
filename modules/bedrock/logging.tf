resource "aws_cloudwatch_log_group" "bedrock_invocations" {
  name              = var.log_group_name
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.cloudwatch_kms_key_arn
}

data "aws_iam_policy_document" "bedrock_logging_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}

data "aws_iam_policy_document" "bedrock_logging_permissions" {
  statement {
    sid    = "BedrockLogsDelivery"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.bedrock_invocations.arn}:*"
    ]
  }

  statement {
    sid    = "BedrockLogsDescribe"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "bedrock_logging" {
  name_prefix        = "${var.name_prefix}-bedrock-logging-"
  assume_role_policy = data.aws_iam_policy_document.bedrock_logging_trust.json
}

resource "aws_iam_role_policy" "bedrock_logging" {
  name_prefix = "logging-"
  role        = aws_iam_role.bedrock_logging.id
  policy      = data.aws_iam_policy_document.bedrock_logging_permissions.json
}

resource "aws_bedrock_model_invocation_logging_configuration" "main" {
  logging_config {
    text_data_delivery_enabled      = true
    image_data_delivery_enabled     = true
    embedding_data_delivery_enabled = true
    video_data_delivery_enabled     = true

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock_invocations.name
      role_arn       = aws_iam_role.bedrock_logging.arn
    }

    s3_config {
      bucket_name = var.bedrock_logs_bucket_id
      key_prefix  = var.log_key_prefix
    }
  }

  depends_on = [
    aws_iam_role_policy.bedrock_logging,
    aws_cloudwatch_log_group.bedrock_invocations,
  ]
}
