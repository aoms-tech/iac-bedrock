variable "name_prefix" {
  description = "Prefix for IAM policy naming."
  type        = string
}

variable "litellm_config_bucket_name" {
  description = "S3 bucket name for LiteLLM config.yaml. If null or empty, uses {name_prefix}-litellm-config-{account_id}."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
