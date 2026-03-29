module "observability" {
  source = "./modules/observability"

  name_prefix      = local.name_prefix
  aws_region       = var.aws_region
  project_name     = var.project_name
  environment      = var.environment
  log_bucket_sse   = true
  log_group_name   = local.bedrock_log_group
  create_dashboard = true
}

module "bedrock" {
  source = "./modules/bedrock"

  name_prefix                = local.name_prefix
  aws_region                 = var.aws_region
  project_name               = var.project_name
  environment                = var.environment
  model_invoke_resource_arns = var.model_invoke_resource_arns

  bedrock_logs_bucket_id = module.observability.bedrock_logs_bucket_id
  cloudwatch_kms_key_arn = module.observability.bedrock_logs_kms_key_arn
  log_group_name         = local.bedrock_log_group
  log_key_prefix         = "model-invocations"
  manage_logging_config  = var.manage_logging_config

  enable_guardrail = var.enable_guardrail

  depends_on = [
    module.observability
  ]
}

module "iam" {
  source = "./modules/iam"

  name_prefix                = local.name_prefix
  bedrock_invoke_policy_arn  = module.bedrock.bedrock_invoke_policy_arn
  teams                      = var.teams
  team_role_trust_principals = var.team_role_trust_principals
  allow_account_root_trust   = var.allow_account_root_trust_principal

  depends_on = [module.bedrock]
}

module "networking" {
  count  = var.enable_bedrock_private_endpoints ? 1 : 0
  source = "./modules/networking"

  name_prefix                     = local.name_prefix
  vpc_id                          = var.vpc_id
  private_subnet_ids              = var.private_subnet_ids
  aws_region                      = var.aws_region
  endpoint_allowed_principal_arns = var.endpoint_allowed_principal_arns
}

locals {
  name_prefix       = "${var.project_name}-${var.environment}"
  bedrock_log_group = "/aws/bedrock/model-invocations"
}
