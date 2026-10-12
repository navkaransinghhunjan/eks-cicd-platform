#!/usr/bin/env bash
# Append one record for this pipeline run to logs/install.log and sync it to S3.
#
# S3 (versioned) is the source of truth: pull the latest copy, append, push back.
# The deploy workflow serialises runs with a concurrency group, so there's no race.
#
# Required env: STATUS (success|failure|cancelled)
# Optional env: ENVIRONMENT APP_NAME NAMESPACE IMAGE_TAG LOGS_BUCKET DEPLOY_START LOG_FILE
#               + GitHub's own GITHUB_ACTOR GITHUB_SHA GITHUB_RUN_ID GITHUB_STEP_SUMMARY
set -euo pipefail

: "${STATUS:?STATUS is required}"
LOG_FILE="${LOG_FILE:-logs/install.log}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
APP_NAME="${APP_NAME:-eks-demo}"
NAMESPACE="${NAMESPACE:-$APP_NAME}"
IMAGE_TAG="${IMAGE_TAG:-n/a}"
ACTOR="${GITHUB_ACTOR:-$(whoami)}"
COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
RUN_ID="${GITHUB_RUN_ID:-local}"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
duration="$(( $(date +%s) - ${DEPLOY_START:-$(date +%s)} ))s"

# Helm revision of the release (n/a if the deploy never reached helm)
helm_rev="$(helm status "$APP_NAME" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"
helm_rev="${helm_rev:-n/a}"

mkdir -p "$(dirname "$LOG_FILE")"

s3_uri=""
if [[ -n "${LOGS_BUCKET:-}" ]]; then
  s3_uri="s3://${LOGS_BUCKET}/install.log"
  if aws s3 ls "$s3_uri" >/dev/null 2>&1; then
    aws s3 cp "$s3_uri" "$LOG_FILE" --only-show-errors
  else
    echo "info: no remote log yet, starting from repo copy"
  fi
fi

line="$(printf '%s | env=%s | app=%s | image=%s | commit=%s | helm_rev=%s | actor=%s | run=%s | status=%s | duration=%s' \
  "$ts" "$ENVIRONMENT" "$APP_NAME" "$IMAGE_TAG" "${COMMIT:0:7}" "$helm_rev" "$ACTOR" "$RUN_ID" "${STATUS^^}" "$duration")"

echo "$line" >> "$LOG_FILE"
echo "$line"

if [[ -n "$s3_uri" ]]; then
  aws s3 cp "$LOG_FILE" "$s3_uri" --only-show-errors \
    || echo "warn: could not upload $LOG_FILE to $s3_uri (repo copy still updated)"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Deployment record"
    echo '```'
    echo "$line"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi
