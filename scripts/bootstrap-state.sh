#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"

echo "Bootstrapping Terraform state backend in $REGION"

# Create state bucket with versioning and encryption
echo "Creating S3 bucket for Terraform state..."
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket brickeye-tfstate-bedrock \
    --region "$REGION" \
    || echo "Bucket may already exist" && true
else
  aws s3api create-bucket \
    --bucket brickeye-tfstate-bedrock \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    || echo "Bucket may already exist" && true
fi

aws s3api put-bucket-versioning \
  --bucket brickeye-tfstate-bedrock \
  --versioning-configuration Status=Enabled \
  --region "$REGION"

aws s3api put-bucket-encryption \
  --bucket brickeye-tfstate-bedrock \
  --server-side-encryption-configuration '{
    "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]
  }' \
  --region "$REGION"

aws s3api put-public-access-block \
  --bucket brickeye-tfstate-bedrock \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --region "$REGION"

echo "S3 bucket ready: brickeye-tfstate-bedrock"

# Create DynamoDB lock table
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name brickeye-tfstate-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" \
  || echo "Table may already exist" && true

echo "DynamoDB table ready: brickeye-tfstate-locks"
echo ""
echo "Bootstrap complete. Run 'terraform init' to configure the backend."