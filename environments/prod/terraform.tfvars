# Tracked in git as prod env source of truth. Run:
# terraform init -backend-config=environments/prod/backend.hcl -var-file=environments/prod/terraform.tfvars

aws_region   = "us-east-1"
environment  = "prod"
project_name = "brickeye-bedrock"

# REQUIRED: account root trust is disabled for production.
# Replace with actual SSO role ARNs for your org.
# allow_account_root_trust_principal = false
# team_role_trust_principals = [
#   # "arn:aws:iam::<ACCOUNT_ID>:role/AWSReservedSSO_Administrator_<HASH>",
# ]

# Prod owns the shared logging resources (one per account/region).
# All Bedrock invocations log to /aws/bedrock/model-invocations regardless of env.
# Dev must set both of these to false.
manage_logging_config = true
manage_log_group      = true

# Guardrail recommended in production.
enable_guardrail = true

# PrivateLink strongly recommended in production.
# enable_bedrock_private_endpoints = true
# vpc_id             = "vpc-xxxxxxxx"
# private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
# endpoint_allowed_principal_arns = [
#   "arn:aws:iam::<ACCOUNT_ID>:role/AWSReservedSSO_Administrator_<HASH>",
# ]

# Optional: constrain allowed models to exactly what prod uses.
# model_invoke_resource_arns = [
#   "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-sonnet-4-6",
# ]

# Cursor cross-account Bedrock role is created automatically when environment = "prod".
# Trusts arn:aws:iam::289469326074:role/roleAssumer by default. After Cursor validates setup,
# set the external ID they provide (confused-deputy protection):
cursor_bedrock_external_id = "cursor-906b4afe-10fe-4504-bbf0-5413dc3ef413"
#
# Optional overrides:
# cursor_cross_account_assumer_role_arn = "arn:aws:iam::289469326074:role/roleAssumer"
# cursor_bedrock_role_name_suffix       = "cursor-bedrock-access"

tags = {
  Team        = "platform"
  Environment = "prod"
}
