# AGENTS.md — Coding Guidelines for iac-bedrock

**Project**: Terraform-based AWS Bedrock baseline infrastructure for Brickeye  
**Language**: HCL (Terraform), Bash  
**Terraform Version**: >= 1.5.0  
**AWS Provider Version**: >= 5.100.0

---

## Build, Lint, and Test Commands

### Initialize Terraform (First Time Only)
```bash
AWS_PROFILE=bedrock-workload terraform init -backend-config=backend.hcl
```

### Validate Terraform Syntax
```bash
terraform validate
```

### Format Check (No Changes)
```bash
terraform fmt -check -recursive
```

### Auto-Format Terraform Files
```bash
terraform fmt -recursive
```

### Plan (Single Environment)
```bash
make plan ENV=dev    # or ENV=prod
```

### Apply (Single Environment)
```bash
make apply ENV=dev
```

### Destroy (Single Environment)
```bash
make destroy ENV=dev
```

### Bootstrap State Backend (Once Per Account)
```bash
AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh us-east-1 <ACCOUNT_ID>
```

### List Models (Helper Script)
```bash
AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models
```

---

## Code Style Guidelines

### Terraform (HCL)

#### Imports & Module Organization
- **No explicit imports** — Terraform auto-discovers `.tf` files in directory
- **Module structure**: Each `modules/*/` contains `main.tf`, `variables.tf`, `outputs.tf`
- **Root module**: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `versions.tf` at repo root
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

## Multi-Environment Workflow

**Workspaces**: Isolate `dev` and `prod` environments  
**State Files**: Stored in single S3 bucket with workspace paths  

```bash
# Always use make for env-aware operations
make plan ENV=dev
make apply ENV=dev
make destroy ENV=dev
```

**Key Variables Per Environment**: Defined in `environments/{env}/terraform.tfvars`

---

## Logging & Debugging

- **Plan output**: Always review before `apply`
- **Apply output**: Capture deployment logs; note resource ARNs for troubleshooting
- **State inspection**: `terraform state list` / `terraform state show <resource>`
- **CloudWatch logs**: Bedrock invocations log to `/aws/bedrock/model-invocations` (singleton per region)

---

## Pre-Commit Checklist (Before Committing)

- [ ] Run `terraform fmt -recursive` on all `.tf` files
- [ ] Run `terraform validate` — no errors
- [ ] Review `terraform plan ENV=dev` output for unintended changes
- [ ] Update `.tfvars.example` if variables change
- [ ] Document sensitive outputs or security implications in comments
- [ ] Confirm secrets stay out of git: default is ignore `*.tfvars`, with exceptions for `environments/dev/terraform.tfvars` and `environments/prod/terraform.tfvars` (source of truth; private repo only)

---

## Common Patterns & Best Practices

### Multiple Environments with Shared Infrastructure
- **Singleton resources** (e.g., Bedrock logging config): Only manage from one workspace (`prod`)
- **Per-env resources**: Teams, IAM roles → managed per workspace
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
- Verify available models per region with `./scripts/bedrock-cli.sh list-models`
- Test iam roles with `assume-role` before production rollout

---

## Debugging Tips

1. **Syntax errors**: `terraform validate`
2. **Plan divergence**: `terraform state show <resource>` vs `terraform refresh`
3. **Missing outputs**: Check `outputs.tf` and run `terraform output -json`
4. **AWS permissions**: Review `AWS_PROFILE` and IAM principal trust relationships
5. **State locking**: Clear stale locks manually if needed: `terraform force-unlock <LOCK_ID>`
