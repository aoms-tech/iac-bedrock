# Brickeye Bedrock model guide (LiteLLM)

This guide matches the models exposed in [`config/config.yaml`](./config/config.yaml) and the IAM allow-list in [`iac/variables.tf`](../../iac/variables.tf). Use it to pick a **LiteLLM `model_name`** and understand **rough cost** before starting work.

---

## How to read this

| Term | Meaning |
|------|---------|
| **MTok** | One million tokens (input and output are billed separately). |
| **Region** | Brickeye defaults to **US East (N. Virginia) (`us-east-1`)**. |
| **Tier** | **Standard** on-demand inference (not Priority, Flex, or Batch unless you opt in elsewhere). |
| **LiteLLM name** | The name you pass to the API (e.g. `claude-sonnet-4-6`). It maps to a Bedrock `model_id` / inference profile in `config.yaml`. |

**Pricing sources (validated for this doc):**

- **Anthropic Claude 4.x** — List prices are published by Anthropic for the Claude API and the same **per-million input/output** figures apply to the Claude 4.x product line; Amazon Bedrock bills the same metered rates for those models in Standard tier. Source: [Anthropic — Pricing](https://www.anthropic.com/pricing) (Sonnet 4.6, Opus 4.6, Haiku 4.5). Always double-check the live row on **[Amazon Bedrock pricing](https://aws.amazon.com/bedrock/pricing/) → Anthropic** for US East (N. Virginia).
- **All other models in the table below** — Pulled from the public **AWS Price List API** for service code `AmazonBedrock`, location **US East (N. Virginia)**, On-Demand, Standard input/output token SKUs (offer publication `2026-03-26` at time of writing). Cross-check: **[Amazon Bedrock pricing](https://aws.amazon.com/bedrock/pricing/)** by provider and model name. Overview: [AWS Documentation — Amazon Bedrock pricing](https://docs.aws.amazon.com/bedrock/latest/userguide/bedrock-pricing.html).

**Important:** AWS updates prices; do **not** use this file for finance or vendor contracts without confirming the current Bedrock pricing page or Cost Explorer.

---

## The four use cases

These line up with how we prioritize models in planning: **coding**, **fast editing** (short rewrites and high-volume tweaks—the fourth use case you had in mind), **research**, and **business writing**.

| Use case | What it means | Optimize for |
|----------|----------------|--------------|
| **Coding** | Implementation, refactors, reviews, codegen, agentic/tool-heavy work | Correctness, multi-step reasoning, codebase fit |
| **Fast editing** | Lint-level fixes, short rewrites, rephrasing, bulk small edits | Latency and **low $/token** |
| **Research** | Long documents, synthesis, comparison, analysis; may include explicit reasoning | Context length, nuance, **watch output length** (reasoning models cost more on the output side) |
| **Business writing** | Stakeholder-ready prose, email, slides copy, polished tone | Clarity, tone control, predictable quality |

---

## 1. Coding

**Goal:** Ship and review code, debug non-trivial issues, use tools or long context reliably.

| Priority | LiteLLM name | Input $/MTok | Output $/MTok | When to use |
|----------|----------------|----------------:|---------------:|-------------|
| 1 — Default balance | `claude-sonnet-4-6` | $3.00 | $15.00 | **Primary choice** for most PRs, refactors, and implementation. Best general coding default. |
| 2 — Hardest problems | `claude-opus-4-6` | $5.00 | $25.00 | When Sonnet is not enough—architecture, subtle bugs, highest-stakes changes. |
| 3 — Strong value / agents | `minimax-m2-5` | $0.30 | $1.20 | High value for agentic and coding-style work; confirm behavior on your repo. |
| 4 — Strong value | `kimi-k2-5` | $0.60 | $3.00 | Strong general + coding; higher output $ than MiniMax—watch long answers. |
| 5 — Lowest $ strong generalist | `deepseek-v3-2` | $0.62 | $1.85 | Cheap vs Claude; great for iteration and cost control; validate on your stack. |
| 6 — Open-weight coding | `qwen3-coder-next` | $0.50 | $1.20 | Coding-focused; good for IDE-style codegen. |
| 7 — Open ecosystem | `mistral-large-3` | $0.50 | $1.50 | Mistral flagship on Bedrock; compare to `mistral-large` (legacy) on price. |
| 8 — Coding / agents (Mistral) | `devstral-2` | $0.40 | $2.00 | Mistral’s coding-oriented line for code-heavy flows. |
| 9 — OSS on Bedrock | `gpt-oss-120b` | $0.15 | $0.60 | Inexpensive; use when policy favors open-weight and task is moderate. |
| 10 — Smaller OSS | `gpt-oss-20b` | $0.07 | $0.30 | Light coding, prototypes, or cost experiments. |

**Also available:** `deepseek-r1` (reasoning-first; **expensive output**, see table below), `qwen3-coder-30b`, `qwen3-next-80b`, `llama-3-3-70b`, `llama-3-70b`, `mistral-large` (older flagship), `amazon-nova-pro`, Z.AI GLM models, `kimi-k2-thinking`.

**Practical notes**

- Prefer **`claude-sonnet-4-6`** unless you have a reason (cost, policy, or experimentation).
- **`mistral-large`** (Large 2402) is **much** more expensive per token than **`mistral-large-3`**—for new work, prefer Large 3 unless you depend on legacy behavior.
- **`llama-3-3-70b`** is far cheaper than **`llama-3-70b`** on Bedrock list price; prefer 3.3 for comparable “open Llama” use cases.

---

## 2. Fast editing

**Goal:** Short rewrites, summaries of small snippets, high-volume chat, “fix this paragraph,” style tweaks.

| Priority | LiteLLM name | Input $/MTok | Output $/MTok | When to use |
|----------|----------------|----------------:|---------------:|-------------|
| 1 | `zai-glm-4-7-flash` | $0.07 | $0.40 | **Cheapest** in our catalog for many edits; great for drafts and pre-writes. |
| 2 | `claude-haiku-4-5` | $1.00 | $5.00 | Fast Anthropic default with strong instruction following. |
| 3 | `gpt-oss-20b` | $0.07 | $0.30 | Very cheap; lighter capability—OK for simple edits. |
| 4 | `qwen3-coder-30b` | $0.15 | $0.60 | Very cheap; good for small-scope coding edits. |

Use **`claude-sonnet-4-6`** only when a fast model clearly isn’t enough—output is **$15/MTok** vs **$0.40/MTok** for GLM 4.7 Flash.

---

## 3. Research

**Goal:** Long-context reading, synthesis, nuanced analysis, comparing sources; sometimes step-by-step reasoning.

| Priority | LiteLLM name | Input $/MTok | Output $/MTok | When to use |
|----------|----------------|----------------:|---------------:|-------------|
| 1 | `claude-sonnet-4-6` | $3.00 | $15.00 | Best **default** for long documents and careful synthesis. |
| 2 | `claude-opus-4-6` | $5.00 | $25.00 | Maximum nuance and depth when cost is acceptable. |
| 3 | `zai-glm-5` | $1.00 | $3.20 | Strong long-context positioning; good research + general mix. |
| 4 | `kimi-k2-5` | $0.60 | $3.00 | Strong reasoning/long-context positioning; watch output cost. |
| 5 | `deepseek-r1` | $1.35 | **$5.40** | Reasoning-heavy; **output price is high** and answers can be long—budget carefully. |
| 6 | `kimi-k2-thinking` | $0.60 | $2.50 | “Thinking” variant—more reasoning-style output; often higher latency. |

**Tip:** For reasoning models (**`deepseek-r1`**, **`kimi-k2-thinking`**), cost scales with **generated** tokens. Ask for concise outputs when possible.

---

## 4. Business writing

**Goal:** Polished stakeholder prose—clear, professional tone; emails, memos, slide bullets, customer-facing text.

| Priority | LiteLLM name | Input $/MTok | Output $/MTok | When to use |
|----------|----------------|----------------:|---------------:|-------------|
| 1 | `claude-sonnet-4-6` | $3.00 | $15.00 | Safe default for **high-quality** business copy. |
| 2 | `amazon-nova-pro` | $0.80 | $3.20 | AWS-native generalist; often cheaper than Sonnet; good “mixed” business + AWS-flavored questions. |
| 3 | `zai-glm-5` | $1.00 | $3.20 | Strong general writing; lower input $ than Sonnet. |
| 4 | `zai-glm-4-7` | $0.60 | $2.20 | Balance of cost vs GLM 5 for everyday business text. |
| 5 | `zai-glm-4-7-flash` | $0.07 | $0.40 | Drafts and first passes only—review before external send. |

Use **`claude-opus-4-6`** only when the piece is **high stakes** and budget allows (**$25/MTok** output).

---

## Full reference — pricing and LiteLLM names

Prices are **Standard on-demand, US East (N. Virginia)** unless noted. Claude 4.x rows follow [Anthropic’s published rates](https://www.anthropic.com/pricing); all others from **AWS Price List API** / [Bedrock pricing](https://aws.amazon.com/bedrock/pricing/) as described in [How to read this](#how-to-read-this).

| LiteLLM name | Input $/MTok | Output $/MTok | Source |
|----------------|-------------:|--------------:|--------|
| `claude-opus-4-6` | $5.00 | $25.00 | Anthropic |
| `claude-sonnet-4-6` | $3.00 | $15.00 | Anthropic |
| `claude-haiku-4-5` | $1.00 | $5.00 | Anthropic |
| `deepseek-r1` | $1.35 | $5.40 | AWS Price List |
| `deepseek-v3-2` | $0.62 | $1.85 | AWS Price List |
| `llama-3-70b` | $2.65 | $3.50 | AWS Price List |
| `llama-3-3-70b` | $0.72 | $0.72 | AWS Price List |
| `mistral-large` | $4.00 | $12.00 | AWS Price List |
| `mistral-large-3` | $0.50 | $1.50 | AWS Price List |
| `devstral-2` | $0.40 | $2.00 | AWS Price List |
| `amazon-nova-pro` | $0.80 | $3.20 | AWS Price List |
| `zai-glm-4-7` | $0.60 | $2.20 | AWS Price List |
| `zai-glm-5` | $1.00 | $3.20 | AWS Price List |
| `zai-glm-4-7-flash` | $0.07 | $0.40 | AWS Price List |
| `kimi-k2-5` | $0.60 | $3.00 | AWS Price List |
| `kimi-k2-thinking` | $0.60 | $2.50 | AWS Price List |
| `minimax-m2-5` | $0.30 | $1.20 | AWS Price List |
| `qwen3-coder-next` | $0.50 | $1.20 | AWS Price List |
| `qwen3-coder-30b` | $0.15 | $0.60 | AWS Price List |
| `qwen3-next-80b` | $0.14 | $1.20 | AWS Price List (Mantle Standard SKU) |
| `gpt-oss-120b` | $0.15 | $0.60 | AWS Price List |
| `gpt-oss-20b` | $0.07 | $0.30 | AWS Price List |

---

## Operational checklist

1. **Bedrock console:** [Model access](https://console.aws.amazon.com/bedrock/) enabled for every model you call.
2. **IAM:** Terraform `model_invoke_resource_arns` covers every `bedrock/...` id in `config.yaml`.
3. **LiteLLM:** After changing `config.yaml`, run [`scripts/push-config.sh`](./scripts/push-config.sh) (S3 + Railway restart + health poll when using that flow), or upload to S3 and restart the proxy manually.
4. **Validate IDs:** From `iac/`: `AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models` and `list-inference-profiles`.

---

## Official links

| Resource | URL |
|----------|-----|
| Amazon Bedrock pricing (by model) | https://aws.amazon.com/bedrock/pricing/ |
| AWS Documentation — Bedrock pricing overview | https://docs.aws.amazon.com/bedrock/latest/userguide/bedrock-pricing.html |
| Anthropic — Claude pricing (Claude 4.x list prices) | https://www.anthropic.com/pricing |
| Claude on Amazon Bedrock (product overview) | https://aws.amazon.com/bedrock/anthropic/ |
