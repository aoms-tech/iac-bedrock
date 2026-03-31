# iac-bedrock

Terraform-based AWS Bedrock baseline for Brickeye with:

- least-privilege model invocation access
- model invocation logging to CloudWatch + S3
- optional Bedrock Guardrails
- optional PrivateLink endpoints for `bedrock` and `bedrock-runtime`
- per-team IAM roles for controlled access

For **Claude Code** and **Cursor** on Brickeye Bedrock, see [INSTRUCTIONS.md](./INSTRUCTIONS.md).

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

Before the first `terraform apply` in an AWS account, bootstrap the remote state backend:

```bash
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh
```

This creates:
- S3 bucket `brickeye-tfstate-bedrock` with versioning, encryption, and public access blocked

**After bootstrap is complete, all other engineers skip the bootstrap script and proceed directly to `terraform init`.**

## Quick Start (All engineers)

```bash
# 1. Bootstrap state infrastructure (once per account)
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh us-east-1 <ACCOUNT_ID>

# 2. Update backend.hcl with the bucket name printed above

# 3. Init
AWS_PROFILE=bedrock-workload terraform init -backend-config=backend.hcl

# 4. Create prod workspace
terraform workspace new prod

# 5. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars

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
- `model_invoke_resource_arns` - allowed Bedrock model/inference-profile ARNs
- `teams` - map of team role names to create
- `team_role_trust_principals` - principals allowed to assume team roles
- `allow_account_root_trust_principal` - set `false` and configure `team_role_trust_principals` with SSO role ARNs
- `enable_bedrock_private_endpoints`, `vpc_id`, `private_subnet_ids` - PrivateLink
- `endpoint_allowed_principal_arns` - required when PrivateLink is enabled
- `enable_guardrail` - create baseline guardrail
- `cursor_cross_account_assumer_role_arn` - Cursor AWS account role ARN for cross-account Bedrock access
- `cursor_bedrock_external_id` - optional external ID for Cursor role trust policy
- `cursor_bedrock_role_name_suffix` - suffix for the Cursor Bedrock IAM role name

## Model Access Notes

- This stack restricts model access by ARN in IAM policy.
- Keep `model_invoke_resource_arns` tightly scoped to the exact model IDs you use.
- Model catalog differs by region/account. Verify with:

```bash
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-inference-profiles
```

## AWS CLI Helper Script

Use `scripts/bedrock-cli.sh` for common commands:

```bash
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh get-logging
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh test-invoke-claude
```

`MODEL_ID` can override the default for `test-invoke-claude`.

## Outputs

After apply, useful outputs include:

- `bedrock_invoke_policy_arn`
- `bedrock_logging_role_arn`
- `bedrock_logs_bucket_name`
- `bedrock_logs_kms_key_arn`
- `cloudwatch_log_group_name`
- `team_role_arns`
- `guardrail_id`
- `cursor_bedrock_role_arn`
- `vpc_endpoint_ids` (if enabled)

## Important Operational Notes

- Bedrock invocation logging configuration is regional and should be managed from a single Terraform state per region/account.
- If PrivateLink is enabled, ensure workloads resolve Bedrock endpoints via private DNS in the target VPC.
- Review IAM trust relationships (`team_role_trust_principals`) and set `allow_account_root_trust_principal = false` before production rollout.
- This stack creates a CMK for Bedrock log encryption and uses it for S3 archive and CloudWatch log group encryption.
- Optional guardrails use **CLASSIC** content policy tier so they work without cross-Region inference for guardrails. To use **STANDARD** tier, enable that feature in Bedrock per AWS docs, then change `tier_name` in `modules/bedrock/guardrails.tf`.

## Traffic Flow Diagram

Without PrivateLink:

```text
[App in VPC/Subnet]
      |
      | HTTPS (TLS)
      v
[Public Bedrock endpoint]
      |
      +--> IAM authz (model ARN policy)
      +--> Bedrock service
      +--> Invocation logs -> CloudWatch + S3 (KMS)
```

With PrivateLink (`bedrock` + `bedrock-runtime` interface endpoints):

```text
[App in VPC/Subnet]
      |
      | HTTPS (TLS)
      v
[VPC Interface Endpoint ENI]
  - Security Group enforcement
  - Endpoint Policy enforcement
      |
      | Private AWS network path
      v
[Bedrock service]
      |
      +--> IAM authz (model ARN policy)
      +--> Invocation logs -> CloudWatch + S3 (KMS)
```

Notes:

- PrivateLink is not a VPN; it provides private connectivity inside AWS.
- TLS in transit is still used in both paths.
- PrivateLink adds network isolation and policy controls at the endpoint layer.

### When To Enable PrivateLink


| Scenario                                                            | Enable PrivateLink?    | Why                                                                                     |
| ------------------------------------------------------------------- | ---------------------- | --------------------------------------------------------------------------------------- |
| Production workloads in private subnets with strict egress controls | Yes                    | Keeps Bedrock calls on private AWS network path and avoids internet egress dependencies |
| Compliance/security requirement for private service connectivity    | Yes                    | Adds endpoint policy + SG enforcement layer in addition to IAM                          |
| Multi-account/shared VPC where you need network-level guardrails    | Yes                    | Centralized control of who can access Bedrock endpoints                                 |
| Quick prototype or short-lived sandbox                              | Optional               | Simpler setup, faster iteration, fewer networking dependencies                          |
| Team has limited VPC/networking capacity right now                  | Optional (phase later) | You can start with IAM + logging + guardrails, then add PrivateLink before production   |


## Repo Structure

```text
.
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
│   ├── networking/
│   └── observability/
└── scripts/
    ├── bedrock-cli.sh
    └── bootstrap-state.sh
```

## Future Hardening Considerations

- Replace wildcard model ARNs with exact model IDs per region.
- Encrypt CloudWatch log groups with a customer-managed KMS key if required by compliance.
- Tighten VPC endpoint policy principals from account root to specific IAM roles.
- Add CloudTrail integration and retention policy per your audit requirements.

