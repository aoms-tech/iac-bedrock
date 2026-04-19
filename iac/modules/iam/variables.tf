variable "name_prefix" {
  type = string
}

variable "bedrock_invoke_policy_arn" {
  type = string
}

variable "teams" {
  type = map(object({
    role_name = string
  }))
}

variable "team_role_trust_principals" {
  description = "IAM principal ARNs allowed to assume team roles."
  type        = list(string)
  default     = []
}

variable "allow_account_root_trust" {
  description = "If true, account root principal is also allowed to assume team roles."
  type        = bool
  default     = false
}

variable "enable_cursor_bedrock_cross_account_role" {
  description = "Create IAM role trusted by Cursor's cross-account assumer for Bedrock invoke (intended for prod only)."
  type        = bool
  default     = false
}

variable "cursor_cross_account_assumer_role_arn" {
  description = "IAM role ARN in Cursor's AWS account allowed to assume the Cursor Bedrock role (sts:AssumeRole)."
  type        = string
  default     = "arn:aws:iam::289469326074:role/roleAssumer"
}

variable "cursor_bedrock_external_id" {
  description = "Optional sts:ExternalId condition on the trust policy. Set after Cursor provides it for confused-deputy protection."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cursor_bedrock_role_name_suffix" {
  description = "Suffix for the Cursor Bedrock IAM role name (full name is name_prefix-suffix)."
  type        = string
  default     = "cursor-bedrock-access"
}

variable "litellm_s3_policy_arn" {
  description = "IAM policy ARN for LiteLLM S3 config bucket access. Use litellm_s3_attachments_enabled (plan-time) to gate attachments; this may be unknown until apply."
  type        = string
  default     = null
  nullable    = true
}

variable "litellm_s3_attachments_enabled" {
  description = "When true, create litellm_s3 policy attachments for users with attach_litellm_s3. Must match root enable_litellm_config_bucket so for_each does not depend on an unknown policy ARN at plan time."
  type        = bool
  default     = false
}

variable "iam_users" {
  description = "IAM users to manage. attach_bedrock_invoke attaches the shared Bedrock invoke policy; attach_litellm_s3 attaches litellm_s3_policy_arn when set; extra_policy_arns adds additional AWS or customer-managed policies; tags are applied as-is to the IAM user."
  type = map(object({
    attach_bedrock_invoke = optional(bool, true)
    attach_litellm_s3     = optional(bool, false)
    extra_policy_arns     = optional(list(string), [])
    tags                  = optional(map(string), {})
  }))
  default = {}
}
