#!/usr/bin/env bash
# One-time: create the versioned, encrypted S3 bucket for Terraform state.
# Usage: scripts/bootstrap-state.sh [region]
set -euo pipefail

REGION="${1:-ap-south-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="eks-cicd-platform-tfstate-${ACCOUNT_ID}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "exists: $BUCKET"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
  echo "created: $BUCKET"
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

cat <<MSG

Next:
  cd terraform
  sed "s/CHANGE-ME-tfstate-123456789012/${BUCKET}/" backend.hcl.example > backend.hcl
  sed "s/CHANGE-ME-tfstate-123456789012/${BUCKET}/" terraform.tfvars.example > terraform.tfvars   # then set admin_principal_arns
MSG
