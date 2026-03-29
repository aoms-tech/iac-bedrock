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

## Quick Start

```bash
# 1. Bootstrap state infrastructure (once per account)
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh us-east-1 <ACCOUNT_ID>

# 2. Update backend.hcl with the bucket name printed above

# 3. Init once (no re-init needed when switching environments)
AWS_PROFILE=bedrock-workload terraform init -backend-config=backend.hcl

# 4. Create workspaces
terraform workspace new dev
terraform workspace new prod

# 5. Copy and edit variables for each env
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
# edit each file
```

## Multi-Environment Workflow

Environments are isolated using Terraform workspaces. State is stored in the same S3 bucket under separate keys:

| Workspace | S3 State Key |
|---|---|
| dev  | `env:/dev/bedrock/terraform.tfstate`  |
| prod | `env:/prod/bedrock/terraform.tfstate` |

Use `make` to run commands — it always selects the correct workspace before plan/apply:

```bash
make plan ENV=dev
make apply ENV=dev

make plan ENV=prod
make apply ENV=prod
```

No `terraform init` needed when switching environments.

### Bedrock logging singleton (`aws_bedrock_model_invocation_logging_configuration`)

Bedrock's invocation logging config is **one per AWS account per region**. In a single-account setup, all invocations log to one shared CloudWatch log group (`/aws/bedrock/model-invocations`) regardless of environment.

- **prod** sets `manage_logging_config = true` — owns the singleton
- **dev** sets `manage_logging_config = false` — does not touch it
- Individual callers are identifiable via `identity.arn` in the log entries

## Configure Variables

Start from `environments/dev/terraform.tfvars.example`.

Key variables:

- `aws_region` - Bedrock region (for example `us-east-1`)
- `project_name` / `environment` - resource naming and tags
- `model_invoke_resource_arns` - allowed Bedrock model/inference-profile ARNs
- `teams` - map of team role names to create
- `team_role_trust_principals` - principals allowed to assume team roles
- `allow_account_root_trust_principal` - compatibility toggle; set `false` in production
- `enable_bedrock_private_endpoints`, `vpc_id`, `private_subnet_ids` - PrivateLink
- `endpoint_allowed_principal_arns` - required when PrivateLink is enabled
- `enable_guardrail` - create baseline guardrail

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
├── Makefile
├── providers.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars.example
│   └── prod/
│       └── terraform.tfvars.example
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

