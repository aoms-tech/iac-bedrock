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

2. Upload config and restart (from apps/litellm — cd there first if needed):
   ./scripts/push-config.sh
   Upload to S3 only: ./scripts/push-config.sh --skip-railway
   Manual S3 upload (from apps/litellm, after editing config/config.yaml):
   aws s3 cp config/config.yaml s3://\$(cd ../../iac && terraform output -raw litellm_config_bucket_name)/config.yaml --region us-east-1

3. Create IAM access key for the LiteLLM user; set Railway variables from .env.example (include RAILWAY_LITELLM_URL for push-config health checks)

4. Open template in browser (or Railway CLI):
   ${RAILWAY_TEMPLATE_URL}

5. In Railway project, set env vars from apps/litellm/.env.example

6. Health: push-config.sh polls /health/liveliness after restart. Manual check:
   curl -sS "\${RAILWAY_LITELLM_URL}/health/liveliness"

Commands:
  $0 print-template   Print RAILWAY_TEMPLATE_URL
  $0 help             This message
EOF
  ;;
esac
