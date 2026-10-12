#!/usr/bin/env bash
# Push Terraform outputs into GitHub Actions repository variables (needs gh CLI, logged in).
# Usage: scripts/set-github-vars.sh   (run from repo root after the first terraform apply)
set -euo pipefail

REPO="${REPO:-navkaransinghhunjan/eks-cicd-platform}"
out() { terraform -chdir=terraform output -raw "$1"; }

STATE_BUCKET="$(awk -F'"' '/^bucket/ {print $2}' terraform/backend.hcl)"

declare -A vars=(
  [AWS_REGION]="$(out region)"
  [CLUSTER_NAME]="$(out cluster_name)"
  [ECR_REPOSITORY]="$(out ecr_repository_url)"
  [LOGS_BUCKET]="$(out logs_bucket)"
  [DEPLOY_ROLE_ARN]="$(out deploy_role_arn)"
  [TF_PLAN_ROLE_ARN]="$(out tf_plan_role_arn)"
  [TF_APPLY_ROLE_ARN]="$(out tf_apply_role_arn)"
  [TF_STATE_BUCKET]="$STATE_BUCKET"
  [TF_ADMIN_PRINCIPAL_ARNS]="$(out admin_principal_arns_json)"
)

for k in "${!vars[@]}"; do
  gh variable set "$k" --repo "$REPO" --body "${vars[$k]}"
  echo "set $k"
done
