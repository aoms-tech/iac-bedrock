# AWS Terraform (`iac/`)

Terraform-based AWS Bedrock baseline for Brickeye with:

- least-privilege model invocation access
- model invocation logging to CloudWatch + S3
- optional Bedrock Guardrails
- optional PrivateLink endpoints for `bedrock` and `bedrock-runtime`
- per-team IAM roles for controlled access
- optional **S3 bucket + IAM policy** for [LiteLLM](https://github.com/BerriAI/litellm) proxy `config.yaml` (see [`../apps/litellm/`](../apps/litellm/))

Run all Terraform commands **from this directory** (`iac/`).

## What This Deploys

- `modules/bedrock`
  - IAM policy for `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` scoped to selected model/inference-profile ARNs
  - CloudWatch log group for Bedrock invocation logs
  - IAM role used by Bedrock to publish logs
  - `aws_bedrock_model_invocation_logging_configuration` to S3 + CloudWatch
  - optional `aws_bedrock_guardrail`
- `modules/observability`
  - S3 bucket for Bedrock invocation log archive
  - bucket policy allowing Bedrock service log delivery
- `modules/iam`
  - team IAM roles with the Bedrock invoke policy attached
  - optional IAM users with Bedrock + LiteLLM S3 config policy
- `modules/litellm` (when `enable_litellm_config_bucket = true`)
  - private S3 bucket (SSE-S3, versioning, block public access, bucket owner enforced)
  - IAM policy for `GetObject` / `PutObject` / `ListBucket` on that bucket only
- `modules/networking` (optional)
  - interface VPC endpoints for Bedrock APIs
  - endpoint security group and endpoint policy

## Prerequisites

- Terraform `>= 1.5.0`
- AWS CLI v2
- AWS credentials configured for the target account
- permissions to create IAM, S3, CloudWatch, and Bedrock resources
- **Terraform state backend bootstrapped** (one-time setup)

## One-Time: Bootstrap Terraform State Backend (Platform team only)

**Responsibility: Platform or DevOps engineer — run once per AWS account.**

```bash
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh
```

This creates an S3 state bucket (see script output). **After bootstrap**, other engineers run `terraform init` only.

## Quick Start (All engineers)

```bash
cd iac

# 1. Bootstrap state infrastructure (once per account) — from iac/
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh us-east-1 <ACCOUNT_ID>

# 2. Update backend.hcl with the bucket name printed above

# 3. Init
AWS_PROFILE=bedrock-workload terraform init -backend-config=backend.hcl

# 4. Create prod workspace
terraform workspace new prod

# 5. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars

# 6. Plan and apply
AWS_PROFILE=bedrock-workload terraform workspace select prod
AWS_PROFILE=bedrock-workload terraform plan -var-file=terraform.tfvars
AWS_PROFILE=bedrock-workload terraform apply -var-file=terraform.tfvars
```

## Configure Variables

Start from `terraform.tfvars.example`.

Key variables:

- `aws_region` - Bedrock region (for example `us-east-1`)
- `project_name` / `environment` - resource naming and tags
- `model_invoke_resource_arns` - allowed Bedrock model/inference-profile ARNs (**must cover every model** referenced in [`../apps/litellm/config/config.yaml.example`](../apps/litellm/config/config.yaml.example))
- `enable_litellm_config_bucket` / `litellm_config_bucket_name` - LiteLLM config bucket
- `teams` - map of team role names to create
- `team_role_trust_principals` - principals allowed to assume team roles
- `allow_account_root_trust_principal` - set `false` and configure `team_role_trust_principals` with SSO role ARNs in production
- PrivateLink: `enable_bedrock_private_endpoints`, `vpc_id`, `private_subnet_ids`, `endpoint_allowed_principal_arns`
- `enable_guardrail` - create baseline guardrail
- Cursor cross-account: `cursor_cross_account_assumer_role_arn`, `cursor_bedrock_external_id`, `cursor_bedrock_role_name_suffix`
- `ignore_tag_key_prefixes` — tag **keys** starting with these prefixes are **not** reconciled by Terraform (AWS provider `ignore_tags`). Defaults `["AKIA", "ASIA"]` so access-key–shaped tag keys added in the console are left alone. Applies to **all** resources in this stack, not only IAM users; add prefixes for other self-managed key patterns, or set to `[]` to turn off. To stop managing **all** tags on IAM users only, use `lifecycle { ignore_changes = [tags, tags_all] }` on `aws_iam_user` instead (then Terraform never updates user tags).

## Model Access and LiteLLM

- IAM restricts `InvokeModel*` to `model_invoke_resource_arns`.
- Every `bedrock/...` model ID in the LiteLLM config must have a matching ARN in Terraform (foundation model and/or inference profile, depending on how you call Bedrock).
- After you change [`../apps/litellm/config/config.yaml`](../apps/litellm/config/config.yaml), use [`../apps/litellm/scripts/push-config.sh`](../apps/litellm/scripts/push-config.sh) to upload to the Terraform S3 bucket and restart the Railway service (see [`../apps/litellm/README.md`](../apps/litellm/README.md)).
- Verify models in-region:

```bash
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-inference-profiles
```

## AWS CLI Helper Script

```bash
cd iac
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh get-logging
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh test-invoke-claude
```

## Outputs

After apply, useful outputs include:

- `bedrock_invoke_policy_arn`
- `bedrock_logging_role_arn`
- `bedrock_logs_bucket_name` / `bedrock_logs_bucket_arn`
- `bedrock_logs_kms_key_arn`
- `cloudwatch_log_group_name`
- `team_role_arns`
- `guardrail_id`
- `cursor_bedrock_role_arn`
- `vpc_endpoint_ids` (if enabled)
- `cloudwatch_dashboard_name`
- `litellm_config_bucket_name` / `litellm_config_bucket_arn` / `litellm_config_s3_policy_arn` (when LiteLLM bucket enabled)

## Important Operational Notes

- Bedrock invocation logging configuration is regional; manage from a single Terraform state per region/account.
- If PrivateLink is enabled, workloads must resolve Bedrock endpoints via private DNS in the target VPC.
- Review IAM trust relationships before production rollout.
- Optional guardrails use **CLASSIC** content policy tier. For **STANDARD** tier, enable per AWS docs, then adjust `modules/bedrock/guardrails.tf`.

## Repo Layout (Terraform)

```text
iac/
├── main.tf
├── backend.tf
├── backend.hcl
├── providers.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
├── modules/
│   ├── bedrock/
│   ├── iam/
│   ├── litellm/
│   ├── networking/
│   └── observability/
└── scripts/
    ├── bedrock-cli.sh
    └── bootstrap-state.sh
```

## Future Hardening Considerations

- Replace wildcard model ARNs with exact model IDs per region where possible.
- Add CloudTrail integration and retention policy per audit requirements.
