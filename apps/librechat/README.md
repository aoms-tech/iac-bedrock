# LibreChat (Railway) → LiteLLM

[LibreChat](https://github.com/danny-avila/LibreChat) is the chat UI; **LiteLLM** (see [`../litellm/`](../litellm/)) is the OpenAI-compatible gateway to **Amazon Bedrock**.

## Flow

```text
Browser → LibreChat (Railway) → LiteLLM (Railway) → AWS Bedrock
```

## Configuration

1. Deploy **LiteLLM** and capture its public URL (e.g. `https://litellm-….up.railway.app`).
2. Copy [`env.example`](./env.example) into Railway for LibreChat.
3. Set:
   - **`OPENAI_API_KEY`** — `LITELLM_MASTER_KEY` from LiteLLM, or a **virtual key** from the LiteLLM admin UI (per-user spend).
   - **`OPENAI_API_BASE`** — `https://<litellm-host>/v1` (adjust if your LiteLLM version uses a different path; confirm with a `curl` to `/v1/models`).

Upstream renames env vars between releases — verify against the pinned LibreChat version’s `.env.example`.

## Template URL

Record your Railway template in `scripts/deploy.sh` (`RAILWAY_TEMPLATE_URL`) or export it when printing:

```bash
chmod +x apps/librechat/scripts/deploy.sh
./apps/librechat/scripts/deploy.sh help
```
