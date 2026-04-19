# Brickeye private Bedrock — employee setup (Claude Code, Cursor & OpenCode)

This guide explains how to point **Claude Code**, **Cursor**, and **OpenCode** at **Brickeye’s Amazon Bedrock** deployment (your AWS account and IAM policies), **not** the public Anthropic API.

**What “private Bedrock” means here**

- Inference runs in **your AWS account** (billing and data handling per AWS Bedrock).
- Access is via **AWS credentials** (or **IAM role assumption** for Cursor’s dashboard flow).
- Model allow-lists are enforced with IAM (see repo Terraform: `iac/modules/bedrock/model_access.tf`).

**Before you start**

1. **AWS access** to the Brickeye Bedrock workload account (SSO user, IAM user, or role you can assume).
2. **AWS CLI v2** with Bedrock commands: `aws bedrock help` should work.
3. **Region** where Bedrock is enabled for Brickeye (default in this repo: `us-east-1` — confirm with Platform).
4. **Model access** in the [Bedrock console](https://console.aws.amazon.com/bedrock/) → **Model access** for the models your team uses.
5. **IAM permission** to invoke those models (typically via the team role/policy created by `iac-bedrock`; ask Platform for the role name or `bedrock_invoke_policy_arn`).

Fill these in for your environment:

| Placeholder | Example | Where to get it |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | `iac/terraform.tfvars` / Platform |
| `AWS_PROFILE` | `bedrock-workload` | Your `~/.aws/config` profile for this account |
| Team invoke role (optional) | `arn:aws:iam::<account>:role/<prefix>-bedrock-platform-invoke` | Terraform output `team_role_arns` |

---

## 1. Claude Code CLI (Amazon Bedrock)

Official reference: [Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock).

### 1.1 Authenticate

Use the same credential chain as Terraform (profile recommended):

```bash
aws sso login --profile YOUR_PROFILE
# or: long-lived keys in ~/.aws/credentials (only if your org allows it)
```

Verify account and identity:

```bash
export AWS_PROFILE=YOUR_PROFILE
aws sts get-caller-identity
```

### 1.2 Enable Bedrock mode

Claude Code requires **explicit** Bedrock flags and region (it does **not** read region from `~/.aws/config` for this path):

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1          # must match Brickeye Bedrock region
export AWS_PROFILE=YOUR_PROFILE    # if you use named profiles
```

Add these to your shell profile (`~/.zshrc`) or use a [Claude Code settings file](https://code.claude.com/en/settings) so they persist.

### 1.3 Point at Brickeye-approved models (pinning)

Bedrock model IDs and **inference profiles** differ by region and org. Platform should give you the exact IDs (or ARNs) allowed by IAM.

Pin models so upgrades do not break when defaults change:

```bash
# Examples only — replace with IDs your org allows (inference profile or foundation model ID)
export ANTHROPIC_MODEL='us.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'
```

You can also use an **application inference profile ARN** as `ANTHROPIC_MODEL` if Platform provisions one.

### 1.4 Optional: Bedrock Guardrails (headers)

If Platform publishes a guardrail ID/version, they may ask you to set headers via Claude Code settings — see [Amazon Bedrock Guardrails in Claude Code docs](https://code.claude.com/docs/en/amazon-bedrock#aws-guardrails).

### 1.5 Verify Claude Code is using Bedrock (not the Anthropic API)

Do **all** of these checks; one alone may not be enough.

1. **Environment is Bedrock mode**  
   In the same shell you launch Claude Code from:
   - `echo $CLAUDE_CODE_USE_BEDROCK` → should be `1`
   - `echo $AWS_REGION` → must match Brickeye’s Bedrock region (Claude Code does not infer this from `~/.aws/config` alone for Bedrock).

2. **No Anthropic cloud API key in play**  
   Unset any Anthropic API key for a quick test (names vary by tool version):
   - `unset ANTHROPIC_API_KEY`  
   If Claude Code still works after restarting, traffic is not relying on api.anthropic.com with a personal key.

3. **Claude Code behavior (documented)**  
   With Bedrock, [Claude Code disables `/login` and `/logout`](https://code.claude.com/docs/en/amazon-bedrock) because auth is AWS-based. If those commands are disabled, that aligns with Bedrock mode.

4. **Same AWS identity can invoke Bedrock**  
   With the same `AWS_PROFILE` / credentials:
   ```bash
   aws sts get-caller-identity
   aws bedrock list-foundation-models --region "$AWS_REGION" --max-items 1
   ```
   If this fails with access denied, fix IAM before trusting Claude Code.

5. **Account-side proof (strongest)**  
   If Platform enabled [model invocation logging](https://docs.aws.amazon.com/bedrock/latest/userguide/model-invocation-logging.html) (this repo does), ask them to confirm a recent request in **CloudWatch** log group `/aws/bedrock/model-invocations` (or your org’s name) with **your IAM principal** in the log metadata—or check **CloudTrail** for `InvokeModel` / `InvokeModelWithResponseStream` from your user/role.

### 1.6 How to **switch models** in Claude Code

| Method | What to do |
| --- | --- |
| **Environment variables** | Set `ANTHROPIC_MODEL` (primary) and/or `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL` to different Bedrock model or inference profile IDs. Restart Claude Code after changes. |
| **Built-in picker** | Use the `/model` command in Claude Code (when available) to choose among configured variants; for per-version ARNs, Platform may supply [`modelOverrides` in settings](https://code.claude.com/docs/en/amazon-bedrock#4-pin-model-versions). |
| **Settings file** | Use `modelOverrides` in the Claude Code JSON settings to map UI labels to ARNs (best for multiple pinned versions). |

**Rule:** Only switch to models that are **enabled in Bedrock** for your account **and** allowed by your IAM policy. If you get `AccessDenied`, ask Platform to add that model ARN to the Terraform allow-list.

---

## 2. Cursor (Amazon Bedrock)

Official reference: [Cursor — AWS Bedrock](https://cursor.com/docs/customizing/aws-bedrock).

Cursor does **not** use the same shell exports as Claude Code. You configure Bedrock **in the Cursor product**:

### 2.1 Recommended: IAM role in Cursor dashboard (enterprise)

1. Open [Cursor dashboard](https://cursor.com/dashboard) → **Settings**.
2. Find **Bedrock IAM Role** (visibility may depend on your org; ask admin if missing).
3. Enter:
   - **AWS IAM Role ARN** — a role in **Brickeye’s account** that can invoke Bedrock (created by Platform / Terraform, or a dedicated `CursorBedrockRole` they attach).
   - **AWS Region** — same as Brickeye Bedrock (e.g. `us-east-1`).
   - **Test Model ID** — a model ID you are allowed to invoke (e.g. an inference profile ID).
4. Cursor will show an **External ID**. Platform must add that External ID to the role’s **trust policy** (Cursor documents this as preventing confused-deputy issues). Do not share the External ID publicly.

**Important:** The trust policy in Cursor’s docs expects Cursor’s service principal (`arn:aws:iam::289469326074:role/roleAssumer` in their documentation). Platform must apply the exact trust + External ID Cursor shows for **your** workspace.

### 2.2 Alternative: Access keys in Cursor IDE (simpler, less secure)

1. Cursor → **Settings** → **Models**.
2. Enter **AWS Access Key ID** and **Secret Access Key** for an IAM user or role credentials in the Brickeye account (only if your security policy allows long-lived keys).

Prefer SSO + short-lived credentials or the dashboard IAM role flow when possible.

### 2.3 How to **switch models** in Cursor

| Method | What to do |
| --- | --- |
| **Cursor model picker** | Settings → Models: choose the Bedrock-backed model / profile your admin enabled. |
| **Dashboard “Test Model ID”** | Used to validate connectivity; changing production default models may be admin-controlled on team plans. |
| **If a model is missing** | Enable it in Bedrock console (Model access) and ensure IAM allows that resource ARN. |

If Cursor and OpenAI keys are both configured, routing can conflict — use only the provider your team standardizes on, or ask admin. See Cursor troubleshooting in their Bedrock doc.

---

## 3. OpenCode (Amazon Bedrock)

[OpenCode](https://opencode.ai/) is a terminal-based coding agent that can use **Amazon Bedrock** as a backend instead of direct cloud API keys. Official setup: [OpenCode — Providers — Amazon Bedrock](https://opencode.ai/docs/providers/#amazon-bedrock).

### 3.1 Prerequisites

Same as the rest of this doc: **Bedrock model access** for the models you need, **IAM allow-list** for those model/inference-profile ARNs (Terraform in this repo), and a working **AWS credential chain** for the Brickeye account.

### 3.2 Authenticate

Pick one pattern (aligns with OpenCode’s documented options):

| Method | What to set |
| --- | --- |
| **Named profile** (recommended with SSO) | `export AWS_PROFILE=YOUR_PROFILE` and `export AWS_REGION=us-east-1` before starting OpenCode |
| **Access keys** | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (only if your org allows long-lived keys) |
| **Bedrock API key** | `AWS_BEARER_TOKEN_BEDROCK` — from the Bedrock console; **takes precedence** over profile/keys when set |
| **EKS / IRSA** | `AWS_WEB_IDENTITY_TOKEN_FILE` + `AWS_ROLE_ARN` (injected in Kubernetes) |

Run `aws sso login --profile YOUR_PROFILE` (if using SSO), then verify with `aws sts get-caller-identity` using the same profile.

### 3.3 Configure Bedrock in `opencode.json` (recommended)

Project or user config can pin region and profile so you do not rely on shell exports alone. Configuration in `opencode.json` **overrides** environment variables for provider options (per OpenCode docs):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "amazon-bedrock": {
      "options": {
        "region": "us-east-1",
        "profile": "YOUR_PROFILE"
      }
    }
  }
}
```

Optional **`endpoint`**: if Brickeye routes Bedrock only through **VPC interface endpoints**, set the `bedrock-runtime` VPC endpoint URL here (same idea as PrivateLink in §4 below).

### 3.4 Choose models

Inside OpenCode, use the **`/models`** command to pick a Bedrock-backed model. For **application inference profiles** or custom ARNs, map a friendly key to the full ARN under `provider.amazon-bedrock.models` (OpenCode uses this for correct caching), for example:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "amazon-bedrock": {
      "options": { "region": "us-east-1", "profile": "YOUR_PROFILE" },
      "models": {
        "brickeye-claude-sonnet": {
          "id": "arn:aws:bedrock:us-east-1:ACCOUNT_ID:application-inference-profile/PROFILE_ID"
        }
      }
    }
  }
}
```

Replace with IDs **your IAM policy allows** (inference profile ID, `us.*` profile, or foundation-model ID — same constraints as Claude Code).

### 3.5 Verify you are on Bedrock

- With **`AWS_BEARER_TOKEN_BEDROCK` unset**, OpenCode should use your **AWS profile / credential chain**; confirm the same identity can call `aws bedrock list-foundation-models --region "$AWS_REGION"`.
- If Platform enabled invocation logging, requests should appear like other Bedrock clients (§1.5).

---

## 4. Private networking (optional)

If Brickeye uses **VPC interface endpoints** for `bedrock` and `bedrock-runtime` (PrivateLink), **only resources inside that VPC** (or connected networks) resolve those private endpoints. Developer laptops usually use **public Bedrock endpoints** unless you are on **VPN / Zero Trust** into a network that uses the VPC DNS for Bedrock.

Ask Platform: *“Do dev machines use PrivateLink, or only services running in AWS?”*

---

## 5. Quick verification (any tool)

```bash
export AWS_PROFILE=YOUR_PROFILE
export AWS_REGION=us-east-1
aws sts get-caller-identity
aws bedrock list-foundation-models --region "$AWS_REGION" --output table
```

From this repo (optional):

```bash
cd iac
./scripts/bedrock-cli.sh list-models
./scripts/bedrock-cli.sh get-logging
```

---

## 6. Where to get help internally

- **IAM / role ARNs / allow-listed models:** Platform or whoever owns `iac-bedrock` Terraform applies.
- **Cursor External ID / dashboard:** Cursor admin + Platform (IAM trust policy update).
- **Claude Code env vars / model IDs:** Platform + [Claude Code Bedrock troubleshooting](https://code.claude.com/docs/en/amazon-bedrock#troubleshooting).
- **OpenCode Bedrock provider / `opencode.json`:** [OpenCode Amazon Bedrock](https://opencode.ai/docs/providers/#amazon-bedrock) + Platform for IAM allow-listed ARNs.

---

## 7. Document change log

| Date | Change |
| --- | --- |
| 2026-03-28 | Employee guide: Claude Code, Cursor, OpenCode on Brickeye Bedrock |
