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
  description = "Environment name."
  type        = string
  default     = "prod"
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
  description = "Bedrock model and inference-profile ARNs for bedrock:InvokeModel / InvokeModelWithResponseStream. Use arn:aws:bedrock:*:*:inference-profile/... (wildcard account); system inference profile ARNs include your account ID and do not match :: (empty account)."
  type        = list(string)
  default = [
    # Latest Anthropic Models (inference-profile ARNs require :*: account segment; foundation-model keeps ::)
    "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-sonnet-4-6",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-6",
    "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
    "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-opus-4-6-v1",
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-opus-4-6-v1",
    # DeepSeek
    "arn:aws:bedrock:*:*:inference-profile/us.deepseek.r1-v1:0",
    "arn:aws:bedrock:*::foundation-model/deepseek.r1-v1:0",
    # MiniMax, Z AI GLM, Moonshot Kimi (foundation-model IDs from list-foundation-models)
    "arn:aws:bedrock:*::foundation-model/minimax.*",
    "arn:aws:bedrock:*::foundation-model/zai.glm*",
    "arn:aws:bedrock:*::foundation-model/moonshot*",
    "arn:aws:bedrock:*::foundation-model/moonshotai.*",
    # Amazon Titan embeddings — include G1 and v1/v2 variants; console "Titan Embeddings G1 – Text" may use
    # amazon.titan-embed-g1-text-02 while older docs use amazon.titan-embed-text-v1 (each has a distinct IAM resource ARN).
    "arn:aws:bedrock:*::foundation-model/amazon.titan-embed-text-v1",
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

variable "cursor_cross_account_assumer_role_arn" {
  description = "Cursor AWS account role allowed to assume the Cursor Bedrock IAM role."
  type        = string
  default     = "arn:aws:iam::289469326074:role/roleAssumer"
}

variable "cursor_bedrock_external_id" {
  description = "External ID for the Cursor Bedrock role trust policy (recommended once Cursor provides it). Omitted from the trust policy when empty."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cursor_bedrock_role_name_suffix" {
  description = "IAM role name suffix for Cursor Bedrock access; full name is {project_name}-{environment}-{suffix}."
  type        = string
  default     = "cursor-bedrock-access"
}

variable "iam_users" {
  description = "IAM users managed by Terraform. attach_bedrock_invoke attaches the shared Bedrock invoke policy; extra_policy_arns adds additional AWS or customer-managed policies; tags are applied as-is to the IAM user."
  type = map(object({
    attach_bedrock_invoke = optional(bool, true)
    extra_policy_arns     = optional(list(string), [])
    tags                  = optional(map(string), {})
  }))
  default = {}
}
