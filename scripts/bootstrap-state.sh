#!/usr/bin/env bash
# bootstrap-state.sh — creates the S3 state bucket.
# Run once per AWS account before `terraform init`.
# Locking uses S3 native lock files (use_lockfile = true) — no DynamoDB needed.
#
# Usage:
#   AWS_PROFILE=bedrock-workload ./scripts/bootstrap-state.sh <region> <account_id>
#
# Arguments:
#   $1  region      (e.g. us-east-1)
#   $2  account_id  (12-digit AWS account ID)

set -euo pipefail

REGION="${1:?Usage: $0 <region> <account_id>}"
ACCOUNT_ID="${2:?Usage: $0 <region> <account_id>}"

BUCKET_NAME="brickeye-terraform-state-${ACCOUNT_ID}"

echo "==> Bootstrapping Terraform state backend"
echo "    Region:  ${REGION}"
echo "    Account: ${ACCOUNT_ID}"
echo "    Bucket:  ${BUCKET_NAME}"
echo ""

# --- S3 bucket ---
if aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
  echo "    [skip] S3 bucket already exists: ${BUCKET_NAME}"
else
  echo "==> Creating S3 bucket: ${BUCKET_NAME}"
  if [ "${REGION}" = "us-east-1" ]; then
    # us-east-1 must NOT specify LocationConstraint (AWS API quirk)
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
fi

echo "==> Enabling bucket versioning"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling default SSE-S3 encryption"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

echo "==> Blocking all public access"
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo ""
echo "Bootstrap complete. Next steps:"
echo "  1. Update backend.hcl: set bucket = \"${BUCKET_NAME}\""
echo "  2. terraform init -backend-config=backend.hcl"
echo "  3. terraform workspace new prod"
