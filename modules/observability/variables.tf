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

variable "log_bucket_sse" {
  description = "Enable default server-side encryption on the logs bucket."
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Create a customer-managed KMS key for Bedrock log encryption."
  type        = bool
  default     = true
}
