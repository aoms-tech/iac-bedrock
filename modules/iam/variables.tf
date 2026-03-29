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
