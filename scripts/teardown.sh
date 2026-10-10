#!/usr/bin/env bash
# Run this with: bash scripts/teardown.sh
# Do NOT source it.

PROJECT_ID="velrite-tf-test"
REPO_DIR="$HOME/project7-ai-inference-platform"
TF_DIR="$REPO_DIR/terraform/environments/dev"

SCRIPT_START=$SECONDS

step() {
  local name="$1"
  echo ""
  echo "### $name ###"
  STEP_START=$SECONDS
}

step_done() {
  echo "--- done in $((SECONDS - STEP_START))s ---"
}

on_error() {
  echo ""
  echo "!! Script hit an error but did NOT close your terminal."
  echo "!! Check the step above this line, fix it, then re-run: bash scripts/teardown.sh"
  echo "!! Elapsed before failure: $((SECONDS - SCRIPT_START))s"
}
trap on_error ERR

step "0. Set the active project (fixes UserProjectInvalid on the GCS backend)"
gcloud config set project "$PROJECT_ID"
gcloud auth application-default set-quota-project "$PROJECT_ID" 2>/dev/null \
  || echo "NOTE: could not set ADC quota project — if step 4 still fails, run: gcloud auth application-default login"
step_done

step "1. Confirm what's running before planning a destroy"
kubectl get pods -A || echo "WARNING: could not reach cluster — check kubectl context."
gcloud container clusters list --project="$PROJECT_ID" || echo "WARNING: could not list clusters — check gcloud auth/project."
step_done

step "2. Disable ArgoCD auto-sync FIRST — otherwise it may fight the teardown"
kubectl patch application project7-inference -n argocd --type merge \
  -p '{"spec":{"syncPolicy":null}}' 2>/dev/null && echo "Auto-sync disabled." \
  || echo "ArgoCD Application not found or already down — continuing."
step_done

step "3. Remove Kyverno's admission webhooks BEFORE destroying the cluster"
echo "(Without this, Kyverno's ValidatingWebhookConfiguration can block deletion"
echo " of resources during teardown if the webhook becomes unreachable mid-destroy.)"
kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg --ignore-not-found=true 2>/dev/null \
  && echo "Removed (or already absent): kyverno-resource-validating-webhook-cfg"
kubectl delete validatingwebhookconfiguration kyverno-policy-validating-webhook-cfg --ignore-not-found=true 2>/dev/null \
  && echo "Removed (or already absent): kyverno-policy-validating-webhook-cfg"
step_done

step "4. Generate destroy plan (PLAN ONLY — nothing is destroyed yet)"
cd "$TF_DIR" || { echo "FATAL: cannot cd to $TF_DIR"; exit 1; }
terraform init -reconfigure
if terraform plan -destroy -out=/tmp/project7-destroy.tfplan | tee /tmp/project7-destroy-plan.txt; then
  echo "Plan written to /tmp/project7-destroy.tfplan"
else
  echo "FATAL: terraform plan -destroy failed — see /tmp/project7-destroy-plan.txt above."
  echo "If you still see UserProjectInvalid, run: gcloud auth application-default login"
  exit 1
fi
step_done

TOTAL=$((SECONDS - SCRIPT_START))
echo ""
echo "=== TEARDOWN PREP COMPLETE in ${TOTAL}s ==="
echo ""
echo "Destroying deletes the WIF pool/provider CI depends on."
echo "CI fails with invalid_target until startup.sh runs again. Expected."
echo ""
echo ">>> REVIEW THE PLAN ABOVE. Should list project7-cluster only —"
echo ">>> nothing belonging to atlas-dev or Forge."
echo ""
echo "If correct, apply it yourself (not run automatically):"
echo "    cd $TF_DIR && terraform apply /tmp/project7-destroy.tfplan"
echo ""
echo "After destroying, verify zero cost:"
echo "    gcloud container clusters list --project=$PROJECT_ID"
echo "    gcloud compute instances list --project=$PROJECT_ID"
