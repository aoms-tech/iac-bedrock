#!/usr/bin/env bash
# apps/litellm/scripts/deploy.sh — reproducible Railway deploy notes for LiteLLM proxy.
# Replace RAILWAY_TEMPLATE_URL with your Brickeye template or upstream one-click URL.
#
# Usage:
#   ./scripts/deploy.sh print-template   # show recorded template URL
#   ./scripts/deploy.sh help

set -euo pipefail

RAILWAY_TEMPLATE_URL="${RAILWAY_TEMPLATE_URL:-https://railway.com/new/template/Lm9gxI}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
iac_dir="${repo_root}/iac"

cmd="${1:-help}"

case "${cmd}" in
print-template)
  echo "Recorded Railway template URL (set RAILWAY_TEMPLATE_URL to override):"
  echo "  ${RAILWAY_TEMPLATE_URL}"
  ;;
help | *)
  cat <<EOF
LiteLLM on Railway — operator checklist (as code)

1. AWS (from ${iac_dir}):
   terraform apply  # enable_litellm_config_bucket, IAM user with attach_litellm_s3
   terraform output litellm_config_bucket_name

2. Upload config:
   aws s3 cp config/config.yaml.example s3://\$(terraform output -raw litellm_config_bucket_name)/config.yaml --region us-east-1
   (edit the local file first; remove .example)

3. Create IAM access key for the LiteLLM user; set Railway variables from .env.example

4. Open template in browser (or Railway CLI):
   ${RAILWAY_TEMPLATE_URL}

5. In Railway project, set env vars from apps/litellm/.env.example

6. Health check:
   curl -sS "\${RAILWAY_LITELLM_URL}/health/liveliness"

Commands:
  $0 print-template   Print RAILWAY_TEMPLATE_URL
  $0 help             This message
EOF
  ;;
esac
