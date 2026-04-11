# LiteLLM proxy config bucket (SSE-S3, versioning, no public access, ACLs disabled).
data "aws_caller_identity" "current" {}

locals {
  bucket_id = (
    var.litellm_config_bucket_name != null && var.litellm_config_bucket_name != ""
    ? var.litellm_config_bucket_name
    : "${var.name_prefix}-litellm-config-${data.aws_caller_identity.current.account_id}"
  )
}

resource "aws_s3_bucket" "litellm_config" {
  bucket = local.bucket_id

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "litellm_config" {
  bucket = aws_s3_bucket.litellm_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "litellm_config" {
  bucket = aws_s3_bucket.litellm_config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "litellm_config" {
  bucket = aws_s3_bucket.litellm_config.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  depends_on = [aws_s3_bucket_public_access_block.litellm_config]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "litellm_config" {
  bucket = aws_s3_bucket.litellm_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "litellm_config_s3" {
  statement {
    sid    = "LiteLLMConfigObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.litellm_config.arn}/*"]
  }

  statement {
    sid    = "LiteLLMConfigListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.litellm_config.arn]
  }
}

resource "aws_iam_policy" "litellm_config_s3" {
  name_prefix = "${var.name_prefix}-litellm-config-s3-"
  description = "Read/write LiteLLM config object in the dedicated S3 bucket"
  policy      = data.aws_iam_policy_document.litellm_config_s3.json
}
