# iac-bedrock

Monorepo for **Brickeye** Bedrock platform work:

| Path | Purpose |
|------|---------|
| [`iac/`](./iac/) | AWS Terraform — Bedrock baseline, IAM, LiteLLM config S3 bucket, observability |
| [`apps/litellm/`](./apps/litellm/) | LiteLLM proxy on Railway — templates, `config.yaml` example, deploy notes |
| [`apps/librechat/`](./apps/librechat/) | LibreChat on Railway — env examples pointing at LiteLLM |

**Terraform commands** run from **`iac/`** (see [`AGENTS.md`](./AGENTS.md)).

**Employee setup** (Claude Code, Cursor, OpenCode on Bedrock): [`INSTRUCTIONS.md`](./INSTRUCTIONS.md).

Detailed AWS stack description: [`iac/README.md`](./iac/README.md).
