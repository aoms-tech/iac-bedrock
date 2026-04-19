#!/usr/bin/env bash
# push-config.sh — upload apps/litellm/config/config.yaml to S3, then restart the Railway service
# so LiteLLM reloads config from the bucket.
#
# Prerequisites: aws CLI, railway CLI; AWS credentials with s3:PutObject on the config bucket;
# Railway project linked (e.g. `railway link` from apps/litellm) or use RAILWAY_* overrides below.
#
# Usage:
#   ./scripts/push-config.sh
#   ./scripts/push-config.sh --skip-railway    # S3 upload only (no Railway prompt)
#   ./scripts/push-config.sh --yes             # skip confirmation (CI / trusted context)
#   CONFIG_PATH=/path/to/config.yaml ./scripts/push-config.sh
#
# Environment (optional):
#   LITELLM_CONFIG_BUCKET_NAME   — S3 bucket (default: from apps/litellm/.env or terraform output in iac/)
#   LITELLM_CONFIG_BUCKET_OBJECT_KEY — object key (default: config.yaml)
#   AWS_REGION / AWS_REGION_NAME — default: us-east-1
#   AWS_PROFILE                  — e.g. bedrock-workload for terraform fallback
#   RAILWAY_SERVICE              — pass to `railway restart --service` when the project has multiple services
#   RAILWAY_LINK_DIR             — directory where `railway link` was run (default: apps/litellm)
#   RAILWAY_LITELLM_URL          — public base URL (health check uses .../health/liveliness unless LITELLM_HEALTH_URL is set)
#   LITELLM_HEALTH_URL           — full URL for post-restart checks (overrides RAILWAY_LITELLM_URL path)
#   HEALTH_POLL_INTERVAL_SECS    — seconds between checks (default: 10)
#   HEALTH_POLL_TIMEOUT_SECS      — max seconds after restart before giving up (default: 180)

set -euo pipefail

HEALTH_POLL_INTERVAL_SECS="${HEALTH_POLL_INTERVAL_SECS:-10}"
HEALTH_POLL_TIMEOUT_SECS="${HEALTH_POLL_TIMEOUT_SECS:-180}"

litellm_health_url() {
  if [[ -n "${LITELLM_HEALTH_URL:-}" ]]; then
    echo "${LITELLM_HEALTH_URL}"
    return 0
  fi
  if [[ -n "${RAILWAY_LITELLM_URL:-}" ]]; then
    local base="${RAILWAY_LITELLM_URL%/}"
    echo "${base}/health/liveliness"
    return 0
  fi
  return 1
}

wait_for_health() {
  local url="$1"
  local start=$SECONDS
  echo "Waiting ${HEALTH_POLL_INTERVAL_SECS}s before first health check, then every ${HEALTH_POLL_INTERVAL_SECS}s (timeout ${HEALTH_POLL_TIMEOUT_SECS}s from restart)..." >&2
  sleep "${HEALTH_POLL_INTERVAL_SECS}"
  while true; do
    if curl -sS -f -o /dev/null --connect-timeout 5 --max-time 20 "${url}"; then
      echo "Health check OK: ${url}" >&2
      return 0
    fi
    if (( SECONDS - start >= HEALTH_POLL_TIMEOUT_SECS )); then
      echo "Health check timed out after ${HEALTH_POLL_TIMEOUT_SECS}s from restart (last URL: ${url})" >&2
      return 1
    fi
    echo "Health check failed, retrying in ${HEALTH_POLL_INTERVAL_SECS}s..." >&2
    sleep "${HEALTH_POLL_INTERVAL_SECS}"
  done
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
litellm_root="$(cd "${script_dir}/.." && pwd)"
repo_root="$(cd "${litellm_root}/../.." && pwd)"
iac_dir="${repo_root}/iac"

skip_railway=false
auto_confirm=false
while [[ $# -gt 0 ]]; do
  case "$1" in
  --skip-railway)
    skip_railway=true
    shift
    ;;
  --yes)
    auto_confirm=true
    shift
    ;;
  -h | --help)
    sed -n '1,25p' "$0"
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

if [[ -f "${litellm_root}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${litellm_root}/.env"
  set +a
fi

config_path="${CONFIG_PATH:-${litellm_root}/config/config.yaml}"
object_key="${LITELLM_CONFIG_BUCKET_OBJECT_KEY:-config.yaml}"
region="${AWS_REGION:-${AWS_REGION_NAME:-us-east-1}}"

if [[ ! -f "${config_path}" ]]; then
  echo "Config file not found: ${config_path}" >&2
  exit 1
fi

bucket="${LITELLM_CONFIG_BUCKET_NAME:-}"
if [[ -z "${bucket}" ]] && [[ -d "${iac_dir}" ]]; then
  if bucket="$(cd "${iac_dir}" && terraform output -raw litellm_config_bucket_name 2>/dev/null)"; then
    :
  else
    bucket=""
  fi
fi

if [[ -z "${bucket}" ]]; then
  cat <<EOF >&2
Set LITELLM_CONFIG_BUCKET_NAME (e.g. in apps/litellm/.env) or run from a machine that can run:
  cd iac && terraform output -raw litellm_config_bucket_name
EOF
  exit 1
fi

if [[ "${skip_railway}" != true ]]; then
  if ! command -v railway >/dev/null 2>&1; then
    echo "railway CLI not found; install from https://docs.railway.com/develop/cli or set PATH." >&2
    echo "Or run with --skip-railway to upload to S3 only." >&2
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required for health checks after restart." >&2
    exit 1
  fi
  railway_cwd="${RAILWAY_LINK_DIR:-${litellm_root}}"
  cat <<EOF >&2

Restart uses the Railway CLI link in this directory:
  ${railway_cwd}

Before continuing: use \`railway link\`, \`railway service\`, or \`railway environment\`
so the linked project and service are the ones you intend to restart. If this project has
multiple services, set RAILWAY_SERVICE to the LiteLLM service name or ID.

EOF
  if [[ -n "${RAILWAY_SERVICE:-}" ]]; then
    echo "RAILWAY_SERVICE is set to: ${RAILWAY_SERVICE}" >&2
  else
    echo "RAILWAY_SERVICE is unset (CLI default service for this link)." >&2
  fi
  echo >&2
  (cd "${railway_cwd}" && railway status) >&2 || {
    echo >&2
    echo "Could not read Railway status (fix link in ${railway_cwd} or set RAILWAY_LINK_DIR)." >&2
    exit 1
  }
  echo >&2
  if ! health_check_url="$(litellm_health_url)"; then
    cat <<EOF >&2
Set RAILWAY_LITELLM_URL (base URL) or LITELLM_HEALTH_URL (full URL) in apps/litellm/.env
for post-restart checks. Default path is /health/liveliness when using RAILWAY_LITELLM_URL.
EOF
    exit 1
  fi
  echo "Health check will use: ${health_check_url}" >&2
  echo >&2
  if [[ "${auto_confirm}" != true ]]; then
    read -r -p "Type y to upload config to S3 and restart this Railway deployment: " reply
    if [[ "${reply}" != "y" ]]; then
      echo "Aborted." >&2
      exit 1
    fi
  fi
fi

echo "Uploading ${config_path} -> s3://${bucket}/${object_key} (region ${region})"
aws s3 cp "${config_path}" "s3://${bucket}/${object_key}" --region "${region}"

if [[ "${skip_railway}" == true ]]; then
  echo "Skipping Railway (--skip-railway)."
  exit 0
fi

restart_args=(--yes --json)
if [[ -n "${RAILWAY_SERVICE:-}" ]]; then
  restart_args=(--service "${RAILWAY_SERVICE}" --yes --json)
fi

railway_cwd="${RAILWAY_LINK_DIR:-${litellm_root}}"
echo "Triggering Railway restart in ${railway_cwd} (reloads proxy to pick up S3 config)..."
(cd "${railway_cwd}" && railway restart "${restart_args[@]}")

wait_for_health "${health_check_url}"

echo "Done."
