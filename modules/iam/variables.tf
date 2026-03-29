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
