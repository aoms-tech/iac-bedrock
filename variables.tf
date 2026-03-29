variable "aws_region" {
  description = "Region where Bedrock is used (models and logging are regional)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for resource names."
  type        = string
  default     = "brickeye-bedrock"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Extra tags applied via provider default_tags."
  type        = map(string)
  default     = {}
}

variable "enable_bedrock_private_endpoints" {
  description = "Create interface VPC endpoints for bedrock and bedrock-runtime."
  type        = bool
  default     = false
}

variable "endpoint_allowed_principal_arns" {
  description = "IAM principals allowed to use Bedrock VPC interface endpoints when PrivateLink is enabled."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.enable_bedrock_private_endpoints || length(var.endpoint_allowed_principal_arns) > 0
    error_message = "endpoint_allowed_principal_arns is required when enable_bedrock_private_endpoints is true."
  }
}

variable "vpc_id" {
  description = "VPC ID for PrivateLink endpoints (required if enable_bedrock_private_endpoints is true)."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_bedrock_private_endpoints || length(var.vpc_id) > 0
    error_message = "vpc_id is required when enable_bedrock_private_endpoints is true."
  }
}

variable "private_subnet_ids" {
  description = "Private subnets for interface endpoints."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.enable_bedrock_private_endpoints || length(var.private_subnet_ids) > 0
    error_message = "private_subnet_ids is required when enable_bedrock_private_endpoints is true."
  }
}

variable "enable_guardrail" {
  description = "Create a minimal Bedrock Guardrail (content filters)."
  type        = bool
  default     = false
}

variable "model_invoke_resource_arns" {
  description = "Bedrock model and inference-profile ARNs for bedrock:InvokeModel / InvokeModelWithResponseStream. Adjust for your region and model IDs."
  type        = list(string)
  default = [
    # Latest Anthropic Models
    "arn:aws:bedrock:*::inference-profile/us.anthropic.claude-sonnet-4-6",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-6",
    "arn:aws:bedrock:*::inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
    "arn:aws:bedrock:*::inference-profile/us.anthropic.claude-opus-4-6-v1",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-opus-4-6-v1",
    # DeepSeek
    "arn:aws:bedrock:*::inference-profile/us.deepseek.r1-v1:0",
    "arn:aws:bedrock:*::foundation-model/deepseek.r1-v1:0",
    # MiniMax, Z AI GLM, Moonshot Kimi (foundation-model IDs from list-foundation-models)
    "arn:aws:bedrock:*::foundation-model/minimax.*",
    "arn:aws:bedrock:*::foundation-model/zai.glm*",
    "arn:aws:bedrock:*::foundation-model/moonshot*",
    "arn:aws:bedrock:*::foundation-model/moonshotai.*",
  ]
}

variable "teams" {
  description = "Map of team keys to IAM role names for Bedrock invoke access."
  type = map(object({
    role_name = string
  }))
  default = {
    platform = {
      role_name = "bedrock-platform-invoke"
    }
  }
}

variable "team_role_trust_principals" {
  description = "IAM principals allowed to assume team Bedrock roles (e.g. root, SSO role ARNs)."
  type        = list(string)
  default     = []
}

variable "allow_account_root_trust_principal" {
  description = "If true, account root is added to team role trust policy. Keep false in production."
  type        = bool
  default     = true

  validation {
    condition     = length(var.team_role_trust_principals) > 0 || var.allow_account_root_trust_principal
    error_message = "Set at least one team_role_trust_principals value, or explicitly allow account root trust."
  }
}
