#!/usr/bin/env bash
# Common AWS CLI commands for Bedrock (read-only / inspection).
# Requires: aws CLI v2, credentials configured for the target account.
# Usage: AWS_REGION=us-east-1 ./scripts/bedrock-cli.sh list-models

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"

cmd="${1:-help}"

case "$cmd" in
  list-models)
    aws bedrock list-foundation-models --by-output-modality TEXT --region "$REGION"
    ;;
  list-inference-profiles)
    if [[ "${2:-}" == "--raw" ]]; then
      aws bedrock list-inference-profiles --region "$REGION"
    else
      aws bedrock list-inference-profiles --region "$REGION" | jq -r '.inferenceProfileSummaries[] | 
        "\(.inferenceProfileId)\n  Name: \(.inferenceProfileName)\n  Models: \(
          if .models then
            (.models | map(if type == "object" then .modelArn else . end) | join(", "))
          else
            "N/A"
          end
        )\n  Status: \(.inferenceProfileStatus)\n"'
    fi
    ;;
  get-logging)
    aws bedrock get-model-invocation-logging-configuration --region "$REGION"
    ;;
  put-logging-note)
    cat <<'NOTE'
Model invocation logging is managed by Terraform (aws_bedrock_model_invocation_logging_configuration).
To change destinations, update modules/bedrock/logging.tf and apply.
NOTE
    ;;
  test-invoke-claude)
    MODEL_ID="${MODEL_ID:-anthropic.claude-3-haiku-20240307-v1:0}"
    # CLI v2 treats --body as base64 for blob params; pass raw JSON via fileb:// + binary format.
    BODY_FILE="$(mktemp)"
    trap 'rm -f "$BODY_FILE"' EXIT
    printf '%s' '{"anthropic_version":"bedrock-2023-05-31","max_tokens":64,"messages":[{"role":"user","content":"Say hello in one sentence."}]}' >"$BODY_FILE"
    aws bedrock-runtime invoke-model \
      --region "$REGION" \
      --model-id "$MODEL_ID" \
      --content-type application/json \
      --accept application/json \
      --cli-binary-format raw-in-base64-out \
      --body "fileb://${BODY_FILE}" \
      /tmp/bedrock-invoke-out.json
    echo "Response written to /tmp/bedrock-invoke-out.json"
    ;;
  help|*)
    echo "Usage: AWS_REGION=$REGION $0 <command>"
    echo "Commands:"
    echo "  list-models              - List text foundation models"
    echo "  list-inference-profiles  - List inference profiles (use --raw for JSON output)"
    echo "  get-logging              - Show model invocation logging configuration"
    echo "  put-logging-note         - Reminder that logging is Terraform-managed"
    echo "  test-invoke-claude       - Invoke Claude Haiku (needs bedrock:InvokeModel)"
    echo "Environment: MODEL_ID overrides default for test-invoke-claude."
    ;;
esac
