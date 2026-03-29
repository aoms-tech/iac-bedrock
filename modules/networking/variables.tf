variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "aws_region" {
  type = string
}

variable "endpoint_allowed_principal_arns" {
  description = "IAM principals allowed to use Bedrock VPC endpoints."
  type        = list(string)
}
