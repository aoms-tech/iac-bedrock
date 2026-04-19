# LiteLLM proxy (Railway)

LiteLLM provides an OpenAI-compatible API and routes traffic to **Amazon Bedrock** (and other providers) using credentials from this repo’s **`iac/`** stack.

**Model catalog (friendly names ↔ Bedrock IDs, Tier 1–2):** [`BEDROCK_MODELS.md`](./BEDROCK_MODELS.md)

## Prerequisites

1. **`iac/terraform apply`** with:
   - `enable_litellm_config_bucket = true`
   - an `iam_users` entry with `attach_bedrock_invoke = true` and `attach_litellm_s3 = true` (see `iac/terraform.tfvars.example`)
2. **Config:** Edit [`config/config.yaml`](./config/config.yaml) (start from [`config/config.yaml.example`](./config/config.yaml.example) if needed) so Bedrock model IDs match `iac` `model_invoke_resource_arns`. Deploy changes with [`scripts/push-config.sh`](./scripts/push-config.sh) (S3 upload, Railway restart, health poll), or upload to S3 and restart the proxy manually.
3. **IAM access key** for that user (created outside Terraform); copy [`.env.example`](./.env.example) to `.env` and set variables (including `RAILWAY_LITELLM_URL` for `push-config.sh`).

## Config accuracy

The example YAML follows LiteLLM proxy docs (`os.environ/VAR`, `general_settings`, `litellm_settings`, `router_settings`). If you upgrade LiteLLM or change caching, re-check [LiteLLM proxy configuration](https://docs.litellm.ai/docs/proxy/configs) — Redis may prefer `host`/`port`/`password` instead of `url` depending on version.

## Railway template

Record your real template URL (Brickeye or community) in `scripts/deploy.sh` as `RAILWAY_TEMPLATE_URL`, or export it when running:

```bash
./scripts/deploy.sh print-template
RAILWAY_TEMPLATE_URL='https://railway.app/template/your-id' ./scripts/deploy.sh print-template
```

## Agent skills (Claude / Cursor)

LiteLLM proxy operations skills (`add-model`, `view-usage`, etc.) live at the **repository root** in [`.claude/skills/`](../../.claude/skills/) (from [litellm-skills](https://github.com/BerriAI/litellm-skills)), which **Claude Code** loads automatically for this project. Upstream `README`, license, and `install.sh` are under [`.claude/skills/litellm-upstream/`](../../.claude/skills/litellm-upstream/). For a global copy, symlink that tree into `~/.claude/skills` or run the upstream installer.

## Operations

```bash
# From repo root
chmod +x apps/litellm/scripts/deploy.sh apps/litellm/scripts/push-config.sh
./apps/litellm/scripts/deploy.sh help

# After editing config/config.yaml: upload to S3 and restart the Railway service
cd apps/litellm && ./scripts/push-config.sh
```

`push-config.sh` reads `LITELLM_CONFIG_BUCKET_NAME` from `apps/litellm/.env` (or falls back to `terraform output` in `iac/`). Set `AWS_PROFILE` if needed for S3, and `RAILWAY_LITELLM_URL` (or `LITELLM_HEALTH_URL`) so it can poll the LiteLLM liveliness endpoint after `railway restart` (10s interval, 3 minute timeout). Before uploading and restarting, it prints Railway link context and asks you to type `y` to confirm (use `--yes` to skip that prompt). Use `RAILWAY_SERVICE` when the project has multiple services, and `RAILWAY_LINK_DIR` if you ran `railway link` from the repo root instead of `apps/litellm`.

After deploy, point API clients at `https://<railway-host>` with `Authorization: Bearer <LITELLM_MASTER_KEY>` (or virtual keys from the LiteLLM UI).
