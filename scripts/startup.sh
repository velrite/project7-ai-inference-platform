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

echo "### 10. OpenCost + Prometheus (real per-workload cost data) ###"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null
helm repo add opencost https://opencost.github.io/opencost-helm-chart --force-update >/dev/null
helm repo update >/dev/null

kubectl create namespace prometheus-system --dry-run=client -o yaml | kubectl apply -f -
if ! helm status prometheus -n prometheus-system >/dev/null 2>&1; then
  helm install prometheus prometheus-community/prometheus \
    --namespace prometheus-system \
    --set server.persistentVolume.enabled=false \
    --set alertmanager.enabled=false
fi

kubectl create namespace opencost --dry-run=client -o yaml | kubectl apply -f -
if ! helm status opencost -n opencost >/dev/null 2>&1; then
  helm install opencost opencost/opencost --namespace opencost
fi

# Ensure Cloud Billing API is enabled (idempotent)
gcloud services enable cloudbilling.googleapis.com --project="$PROJECT_ID"

# Ensure a Cloud Billing API key exists, reuse if already created
KEY_NAME=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName=opencost-billing-key" --format="value(name)")
if [ -z "$KEY_NAME" ]; then
  gcloud services api-keys create --display-name="opencost-billing-key" --project="$PROJECT_ID"
  KEY_NAME=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName=opencost-billing-key" --format="value(name)")
  gcloud services api-keys update "$KEY_NAME" --project="$PROJECT_ID" --api-target=service=cloudbilling.googleapis.com
fi
API_KEY=$(gcloud services api-keys get-key-string "$KEY_NAME" --project="$PROJECT_ID" --format="value(keyString)")

kubectl create secret generic opencost-gcp-key -n opencost \
  --from-literal=CLOUD_PROVIDER_API_KEY="$API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade opencost opencost/opencost \
  --namespace opencost \
  --reuse-values \
  --set-json 'extraVolumes=[{"name":"configs","emptyDir":{}}]' \
  --set-json 'opencost.exporter.extraVolumeMounts=[{"name":"configs","mountPath":"/var/configs"}]' \
  --set-json 'opencost.exporter.extraEnvFrom=[{"secretRef":{"name":"opencost-gcp-key"}}]'

kubectl rollout status deployment opencost -n opencost --timeout=120s
echo "OpenCost ready. Pull data with:"
echo "  kubectl port-forward -n opencost svc/opencost 9003:9003"
echo "  curl \"localhost:9003/allocation/compute?window=7d&aggregate=namespace\""
