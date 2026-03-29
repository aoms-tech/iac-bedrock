variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "model_invoke_resource_arns" {
  type = list(string)
}

variable "bedrock_logs_bucket_id" {
  type = string
}

variable "log_group_name" {
  type    = string
  default = "/aws/bedrock/model-invocations"
}

variable "log_key_prefix" {
  type    = string
  default = "model-invocations"
}

variable "cloudwatch_log_retention_days" {
  type    = number
  default = 90
}

variable "enable_guardrail" {
  type    = bool
  default = false
}

variable "cloudwatch_kms_key_arn" {
  description = "KMS key ARN for encrypting CloudWatch Bedrock invocation logs."
  type        = string
}

variable "manage_logging_config" {
  description = "Set false on secondary stacks sharing the same account/region to skip owning aws_bedrock_model_invocation_logging_configuration. Only one stack per account/region should own this singleton."
  type        = bool
  default     = true
}

variable "manage_log_group" {
  description = "Set false on secondary stacks sharing the same account/region to skip creating the CloudWatch log group (it already exists, owned by the primary stack)."
  type        = bool
  default     = true
}
