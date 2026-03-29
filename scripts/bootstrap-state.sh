#!/usr/bin/env bash
# bootstrap-state.sh — creates the S3 state bucket + DynamoDB lock table.
# Run once per AWS account before `terraform init`.
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
TABLE_NAME="brickeye-terraform-locks"

echo "==> Bootstrapping Terraform state backend"
echo "    Region:   ${REGION}"
echo "    Account:  ${ACCOUNT_ID}"
echo "    Bucket:   ${BUCKET_NAME}"
echo "    DynamoDB: ${TABLE_NAME}"
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

# --- DynamoDB lock table ---
if aws dynamodb describe-table \
     --table-name "${TABLE_NAME}" \
     --region "${REGION}" \
     --query 'Table.TableStatus' \
     --output text 2>/dev/null | grep -qE "^ACTIVE$"; then
  echo "    [skip] DynamoDB table already exists: ${TABLE_NAME}"
else
  echo "==> Creating DynamoDB lock table: ${TABLE_NAME}"
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  echo "==> Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${REGION}"
fi

echo ""
echo "Bootstrap complete. Next steps:"
echo "  1. Update environments/<env>/backend.hcl: set bucket = \"${BUCKET_NAME}\""
echo "  2. terraform init -backend-config=environments/<env>/backend.hcl \\"
echo "       -var-file=environments/<env>/terraform.tfvars"
