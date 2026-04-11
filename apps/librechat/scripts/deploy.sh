#!/usr/bin/env bash
# apps/librechat/scripts/deploy.sh — reproducible Railway deploy notes for LibreChat → LiteLLM.
#
# Usage:
#   ./scripts/deploy.sh help

set -euo pipefail

RAILWAY_TEMPLATE_URL="${RAILWAY_TEMPLATE_URL:-https://railway.app/template/REPLACE_ME_LIBRECHAT}"

cmd="${1:-help}"

case "${cmd}" in
print-template)
  echo "Recorded Railway template URL (set RAILWAY_TEMPLATE_URL to override):"
  echo "  ${RAILWAY_TEMPLATE_URL}"
  ;;
help | *)
  cat <<EOF
LibreChat on Railway — operator checklist

1. Deploy LiteLLM first; note its public HTTPS origin (see ../litellm/README.md).

2. Set env vars from ../librechat/env.example:
   - OPENAI_API_KEY = LiteLLM master key or virtual key
   - OPENAI_API_BASE = https://<litellm-host>/v1

3. Deploy LibreChat from Railway template or Dockerfile:
   ${RAILWAY_TEMPLATE_URL}

4. Confirm LibreChat version and env names against:
   https://github.com/danny-avila/LibreChat/blob/main/.env.example

Commands:
  $0 print-template
  $0 help
EOF
  ;;
esac
