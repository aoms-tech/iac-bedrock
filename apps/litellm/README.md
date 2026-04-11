# LiteLLM proxy (Railway)

LiteLLM provides an OpenAI-compatible API and routes traffic to **Amazon Bedrock** (and other providers) using credentials from this repo’s **`iac/`** stack.

## Prerequisites

1. **`iac/terraform apply`** with:
   - `enable_litellm_config_bucket = true`
   - an `iam_users` entry with `attach_bedrock_invoke = true` and `attach_litellm_s3 = true` (see `iac/terraform.tfvars.example`)
2. **Upload** [`config/config.yaml.example`](./config/config.yaml.example) to the S3 bucket (as `config.yaml`), after aligning model IDs with `iac` `model_invoke_resource_arns`.
3. **IAM access key** for that user (created outside Terraform); set Railway variables from [`.env.example`](./.env.example).

## Config accuracy

The example YAML follows LiteLLM proxy docs (`os.environ/VAR`, `general_settings`, `litellm_settings`, `router_settings`). If you upgrade LiteLLM or change caching, re-check [LiteLLM proxy configuration](https://docs.litellm.ai/docs/proxy/configs) — Redis may prefer `host`/`port`/`password` instead of `url` depending on version.

## Railway template

Record your real template URL (Brickeye or community) in `scripts/deploy.sh` as `RAILWAY_TEMPLATE_URL`, or export it when running:

```bash
./scripts/deploy.sh print-template
RAILWAY_TEMPLATE_URL='https://railway.app/template/your-id' ./scripts/deploy.sh print-template
```

## Operations

```bash
# From repo root
chmod +x apps/litellm/scripts/deploy.sh
./apps/litellm/scripts/deploy.sh help
```

After deploy, point API clients at `https://<railway-host>` with `Authorization: Bearer <LITELLM_MASTER_KEY>` (or virtual keys from the LiteLLM UI).
