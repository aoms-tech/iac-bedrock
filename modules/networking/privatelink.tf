data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "bedrock_endpoints" {
  name_prefix = "${var.name_prefix}-bedrock-vpce-"
  description = "HTTPS from VPC to Bedrock interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "bedrock_endpoint" {
  statement {
    sid    = "AllowSelectedPrincipalsUseOfEndpoint"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.endpoint_allowed_principal_arns
    }
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel",
      "bedrock:GetInferenceProfile",
      "bedrock:ListInferenceProfiles",
    ]
    resources = ["*"]
  }
}

locals {
  bedrock_services = {
    bedrock         = "com.amazonaws.${var.aws_region}.bedrock"
    bedrock_runtime = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  }
}

resource "aws_vpc_endpoint" "bedrock" {
  for_each = local.bedrock_services

  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.bedrock_endpoints.id]
  private_dns_enabled = true

  policy = data.aws_iam_policy_document.bedrock_endpoint.json

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}
