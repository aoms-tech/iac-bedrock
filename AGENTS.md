# AGENTS.md — Coding Guidelines for iac-bedrock

**Project**: Terraform-based AWS Bedrock baseline infrastructure for Brickeye  
**Language**: HCL (Terraform), Bash  
**Terraform Version**: >= 1.5.0  
**AWS Provider Version**: >= 5.100.0  

**Terraform root module** lives in **`iac/`**. Run `terraform` / `terraform fmt` / `terraform validate` with **`iac` as the current working directory** unless noted otherwise.

---

## Build, Lint, and Test Commands

### Initialize Terraform (First Time Only)

```bash
cd iac
AWS_PROFILE=bedrock-workload terraform init -backend-config=backend.hcl
```

### Validate Terraform Syntax

```bash
cd iac && terraform validate
```

### Format Check (No Changes)

```bash
cd iac && terraform fmt -check -recursive
```

### Auto-Format Terraform Files

```bash
cd iac && terraform fmt -recursive
```

### Plan

```bash
cd iac
AWS_PROFILE=bedrock-workload terraform plan -var-file=terraform.tfvars
```

### Apply

```bash
cd iac
AWS_PROFILE=bedrock-workload terraform apply -var-file=terraform.tfvars
```

### Destroy

```bash
cd iac
AWS_PROFILE=bedrock-workload terraform destroy -var-file=terraform.tfvars
```

### Bootstrap State Backend (Once Per Account)

```bash
cd iac
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh us-east-1 <ACCOUNT_ID>
```

### List Models (Helper Script)

```bash
cd iac
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models
```

---

## Code Style Guidelines

### Terraform (HCL)

#### Imports & Module Organization

- **No explicit imports** — Terraform auto-discovers `.tf` files in directory
- **Module structure**: Each `modules/*/` contains `main.tf`, `variables.tf`, `outputs.tf`
- **Root module**: `iac/main.tf`, `iac/variables.tf`, `iac/outputs.tf`, `iac/providers.tf`, `iac/versions.tf`
- **Module calls**: Place in `main.tf` with clear variable assignments

#### Formatting & Spacing

- **Automatic formatting**: Use `terraform fmt -recursive` before commit
- **Block alignment**: 2-space indentation (terraform fmt enforces)
- **Line wrapping**: Keep logical groupings together; wrap at ~100 chars for readability
- **Comments**: Prefix resource blocks with `#` comments explaining purpose or AWS-specific quirks

#### Naming Conventions

- **Resources**: Use `snake_case` for logical names
  - Example: `aws_s3_bucket.bedrock_logs`, `aws_iam_role.team_invoke`
- **Variables**: Use `snake_case`, prefix with context if multiple per module
  - Example: `model_invoke_resource_arns`, `enable_bedrock_private_endpoints`
- **Outputs**: Use `snake_case`, describe what is exported
  - Example: `bedrock_invoke_policy_arn`, `team_role_arns`
- **Local values**: Use `snake_case` for computed/intermediate values
  - Example: `local.log_group_name`

#### Variable Definitions

- **Type declarations**: Always include explicit `type` (e.g., `string`, `list(string)`, `map(string)`)
- **Descriptions**: Mandatory for all inputs; use concise descriptions
- **Defaults**: Optional; provide sensible defaults where applicable
- **Validation**: Use `validation` blocks for complex constraints (e.g., ARN format, allowed values)

#### Resource Declarations

- **Lifecycle rules**: Use `lifecycle { create_before_destroy = true }` for zero-downtime updates
- **Dependencies**: Explicit with `depends_on` only when implicit dependencies insufficient
- **Conditionals**: Use `count` or `for_each` for optional resources; prefer `count` for simple toggles
- **Data sources**: Use for AWS account metadata, VPC lookups, availability zones
- **Dynamic blocks**: Use `dynamic` for repeated nested blocks (e.g., multiple policy statements)

#### Error Handling & Security

- **IAM policies**: Always use explicit `Principal` restrictions; avoid wildcards in `Resource` unless intentional
- **Data sensitivity**: Mark sensitive outputs with `sensitive = true`
- **Key management**: Use customer-managed KMS keys for logs; never rely on AWS-managed keys in prod
- **Tags**: Apply consistently across all resources; use locals for common tag maps

#### JSON & Template Files

- **Inline JSON**: Keep IAM policy documents readable; use `jsonencode()` for dynamic policies
- **Templates**: Use `.tftpl` files with `templatefile()` for CloudWatch dashboards, policies
- **Validation**: Test `terraform validate` after policy changes

### Bash Scripts

#### File Header & Safety

```bash
#!/usr/bin/env bash
# script-name.sh — brief description.
# Usage: ./script-name.sh [arg1] [arg2]

set -euo pipefail  # Exit on error, undefined vars, pipe failure
```

#### Error Handling

- Use `set -euo pipefail` in all scripts
- Provide meaningful error messages with `>&2` redirect
- Use `${VAR:?Error message}` for required parameters

#### Variable Naming

- **Environment variables**: `UPPER_SNAKE_CASE` (e.g., `AWS_PROFILE`, `REGION`)
- **Local variables**: `lower_snake_case`
- **Constants**: `UPPER_SNAKE_CASE` at top of script

#### Code Style

- **Quotes**: Double-quote all variable expansions: `"${VAR}"` not `$VAR`
- **Conditionals**: Use `[[ ]]` for tests (not `[ ]`)
- **Functions**: Use `function_name() { }` syntax; call without `function` keyword
- **Comments**: Explain *why*, not *what*; avoid obvious comments

---

## Workflow

**Workspace**: Single `prod` workspace  
**State File**: Stored in S3 at `env:/prod/bedrock/terraform.tfstate`

```bash
cd iac
AWS_PROFILE=bedrock-workload terraform workspace select prod
AWS_PROFILE=bedrock-workload terraform plan -var-file=terraform.tfvars
AWS_PROFILE=bedrock-workload terraform apply -var-file=terraform.tfvars
```

**Variables**: Defined in `iac/terraform.tfvars` (gitignored; use `iac/terraform.tfvars.example` as template)

---

## Logging & Debugging

- **Plan output**: Always review before `apply`
- **Apply output**: Capture deployment logs; note resource ARNs for troubleshooting
- **State inspection**: `terraform state list` / `terraform state show <resource>`
- **CloudWatch logs**: Bedrock invocations log to `/aws/bedrock/model-invocations` (singleton per region)

---

## Pre-Commit Checklist (Before Committing)

- Run `terraform fmt -recursive` on all `.tf` files
- Run `terraform validate` — no errors
- Review `terraform plan` output for unintended changes
- Update `iac/terraform.tfvars.example` if variables change
- Document sensitive outputs or security implications in comments
- Confirm `terraform.tfvars` stays out of git (gitignored)

---

## Common Patterns & Best Practices

### Single Environment (prod)

- All resources are managed from the `prod` workspace
- **Reference outputs**: Use `terraform output` to pass ARNs between stacks

### Optional Features with Conditionals

```hcl
resource "aws_vpc_endpoint" "bedrock" {
  count = var.enable_bedrock_private_endpoints ? 1 : 0
  # ...
}

output "vpc_endpoint_ids" {
  value = var.enable_bedrock_private_endpoints ? aws_vpc_endpoint.bedrock[*].id : null
}
```

### Tight IAM Scoping

- Use explicit model ARNs in `bedrock:InvokeModel` policies; avoid wildcards
- Verify available models per region with `cd iac && ./scripts/bedrock-cli.sh list-models`
- Test iam roles with `assume-role` before production rollout

---

## Debugging Tips

1. **Syntax errors**: `terraform validate`
2. **Plan divergence**: `terraform state show <resource>` vs `terraform refresh`
3. **Missing outputs**: Check `outputs.tf` and run `terraform output -json`
4. **AWS permissions**: Review `AWS_PROFILE` and IAM principal trust relationships
5. **State locking**: Clear stale locks manually if needed: `terraform force-unlock <LOCK_ID>`

