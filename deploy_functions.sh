#!/bin/bash

# Deploy public callable functions + ensure required Cloud Run invoker bindings.
#
# Why this exists:
# - Firebase Gen2 callable functions run on Cloud Run.
# - In some setups, the Cloud Run service IAM can end up missing the allUsers
#   `roles/run.invoker` binding, causing clients to see:
#   `[firebase_functions/internal] internal`
#   even though the function code never runs.
#
# Notes:
# - `chatCompletion` is still protected at the *function* level via Firebase Auth
#   checks (anonymous auth is fine). This IAM binding only allows the request to
#   reach the function.

set -euo pipefail

PROJECT_ID="pet-underwriter-ai"
REGION="us-central1"

echo "🚀 Deploying Functions (Gen2 callables)..."

firebase deploy --only \
  functions:chatCompletion,functions:analyzeRisk,functions:analyzeClaimDocument,functions:makeClaimDecision,functions:processClaimDecision,functions:getUnderwritingRulesPublic,functions:getProductCatalogPublic

echo "✅ Functions deployed"

echo "🔐 Ensuring Cloud Run invoker bindings..."

# Required so Firebase callable requests can reach the backing Cloud Run service.
gcloud run services add-iam-policy-binding chatcompletion \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null

gcloud run services add-iam-policy-binding analyzerisk \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null || true

gcloud run services add-iam-policy-binding analyzeclaimdocument \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null || true

gcloud run services add-iam-policy-binding makeclaimdecision \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null || true

gcloud run services add-iam-policy-binding processclaimdecision \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null || true

# These should already be public, but keep it idempotent.
gcloud run services add-iam-policy-binding getunderwritingrulespublic \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null || true

gcloud run services add-iam-policy-binding getproductcatalogpublic \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  >/dev/null || true

echo "✅ Cloud Run invoker bindings ensured"

echo "✨ Done"
