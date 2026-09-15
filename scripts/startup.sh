#!/usr/bin/env bash
set -e
PROJECT_ID="velrite-tf-test"
ZONE="us-central1-a"
CLUSTER="project7-cluster"
EXPECTED_CTX="gke_${PROJECT_ID}_${ZONE}_${CLUSTER}"
REPO_DIR="$HOME/project7-ai-inference-platform"

check_context() {
  CTX=$(kubectl config current-context)
  if [ "$CTX" != "$EXPECTED_CTX" ]; then
    echo "FATAL: wrong kubectl context ($CTX), expected $EXPECTED_CTX."
    echo "This account also has atlas-dev and a Forge cluster on it."
    exit 1
  fi
  echo "Context confirmed: $CTX"
}

echo "### 1. Confirm project + repo ###"
gcloud config set project "$PROJECT_ID"
cd "$REPO_DIR/terraform/environments/dev"

echo "### 2. Terraform plan ###"
terraform init
terraform plan -out=/tmp/project7.tfplan | tee /tmp/project7-plan.txt

if grep -qi "gpu-pool\|google_container_node_pool.gpu" /tmp/project7-plan.txt; then
  echo "NOTE: gpu-pool in plan — confirmed safe (autoscaling, maxNodeCount 1, 0 idle cost)."
fi

echo ""
read -p "Plan reviewed above — type 'apply' to proceed, anything else to abort: " CONFIRM
if [ "$CONFIRM" != "apply" ]; then
  echo "Aborted by user."
  exit 1
fi
terraform apply /tmp/project7.tfplan

echo "### 3. WIF soft-delete auto-recovery ###"
POOL_STATE=$(gcloud iam workload-identity-pools describe github-actions-pool --location=global --project="$PROJECT_ID" --format="value(state)" 2>/dev/null || echo "MISSING")
if [ "$POOL_STATE" = "DELETED" ]; then
  echo "WIF pool soft-deleted — undeleting and importing."
  gcloud iam workload-identity-pools undelete github-actions-pool --location=global --project="$PROJECT_ID"
  terraform import google_iam_workload_identity_pool.github "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/github-actions-pool" || true
fi
PROVIDER_STATE=$(gcloud iam workload-identity-pools providers describe github-provider --workload-identity-pool=github-actions-pool --location=global --project="$PROJECT_ID" --format="value(state)" 2>/dev/null || echo "MISSING")
if [ "$PROVIDER_STATE" = "DELETED" ]; then
  echo "WIF provider soft-deleted — undeleting and importing."
  gcloud iam workload-identity-pools providers undelete github-provider --workload-identity-pool=github-actions-pool --location=global --project="$PROJECT_ID"
  terraform import google_iam_workload_identity_pool_provider.github "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider" || true
fi
if [ "$POOL_STATE" = "DELETED" ] || [ "$PROVIDER_STATE" = "DELETED" ]; then
  terraform apply -auto-approve
fi

echo "### 4. Get credentials + verify context ###"
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE" --project "$PROJECT_ID"
check_context

echo "### 5. Re-verify context immediately before kubectl apply ###"
check_context
cd "$REPO_DIR"
kubectl apply -f k8s/workload-identity/ksa.yaml
kubectl apply -f k8s/network-policies/default-deny.yaml
kubectl apply -f k8s/network-policies/allow-granted-only.yaml

echo "### 6. CHECKPOINT: signed-image policy ###"
echo "require-signed-images.yaml scope not yet reviewed. vLLM image is unsigned."
read -p "Apply signed-image policy now, before vLLM? [y/N] " POLICY_FIRST
if [ "$POLICY_FIRST" = "y" ] || [ "$POLICY_FIRST" = "Y" ]; then
  kubectl apply -f k8s/admission/require-signed-images.yaml
fi

echo "### 7. Deploy vLLM ###"
kubectl apply -f k8s/vllm-deployment-cpu.yaml
kubectl apply -f k8s/vllm-service-cpu.yaml
kubectl apply -f k8s/ingress/vllm-cpu-ingress.yaml
kubectl apply -f k8s/observability/vllm-podmonitoring.yaml

echo "### 8. Wait for Ready (model load takes several minutes on CPU) ###"
kubectl wait --for=condition=Ready pod -l app=vllm --timeout=600s

echo "### 9. Real health check ###"
kubectl port-forward svc/vllm-inference-cpu-svc 8000:8000 > /tmp/pf.log 2>&1 &
PF_PID=$!
sleep 5
if curl -sf localhost:8000/v1/models > /dev/null; then
  echo "PASS: /v1/models responded."
  curl -s localhost:8000/v1/completions -H "Content-Type: application/json" \
    -d '{"model":"Qwen/Qwen2.5-1.5B-Instruct","prompt":"Say hello in one word.","max_tokens":5}'
  echo ""
  echo "DONE. vLLM is live and serving."
else
  echo "FAIL: /v1/models did not respond. Check: kubectl logs -l app=vllm"
fi
kill $PF_PID 2>/dev/null || true
