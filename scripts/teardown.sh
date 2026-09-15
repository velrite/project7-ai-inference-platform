#!/usr/bin/env bash
set -e
PROJECT_ID="velrite-tf-test"
REPO_DIR="$HOME/project7-ai-inference-platform"
TF_DIR="$REPO_DIR/terraform/environments/dev"

echo "### 1. Confirm what's running before planning a destroy ###"
kubectl get pods -A
gcloud container clusters list --project="$PROJECT_ID"

echo "### 2. Disable ArgoCD auto-sync FIRST — otherwise it may fight the teardown ###"
kubectl patch application project7-inference -n argocd --type merge \
  -p '{"spec":{"syncPolicy":null}}' 2>/dev/null || echo "ArgoCD not present or already down — continuing."

echo "### 3. Remove Kyverno's admission webhooks BEFORE destroying the cluster ###"
echo "!! Without this, Kyverno's ValidatingWebhookConfiguration can block deletion"
echo "!! of resources during teardown if the webhook becomes unreachable mid-destroy."
kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg --ignore-not-found=true 2>/dev/null || true
kubectl delete validatingwebhookconfiguration kyverno-policy-validating-webhook-cfg --ignore-not-found=true 2>/dev/null || true

echo "### 4. Generate destroy plan (PLAN ONLY) ###"
cd "$TF_DIR"
terraform plan -destroy -out=/tmp/project7-destroy.tfplan | tee /tmp/project7-destroy-plan.txt

echo ""
echo "!! Destroying deletes the WIF pool/provider CI depends on."
echo "!! CI fails with invalid_target until startup.sh runs again. Expected."
echo ""
echo ">>> REVIEW THE PLAN ABOVE. Should list project7-cluster only —"
echo ">>> nothing belonging to atlas-dev or Forge."
echo ""
echo "If correct, apply it yourself:"
echo "    cd $TF_DIR && terraform apply /tmp/project7-destroy.tfplan"
echo ""
echo "After destroying, verify zero cost:"
echo "    gcloud container clusters list --project=$PROJECT_ID"
echo "    gcloud compute instances list --project=$PROJECT_ID"
