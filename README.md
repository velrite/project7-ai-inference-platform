# Project 7 — AI Inference Platform (GKE)

**Author:** Olamide (Velrite) — GitHub: velrite
**Purpose of this document:** A complete enough record that someone could
rebuild this project from zero by following it in order, without needing
to ask anyone (or any AI) what to do next. Where the real source wasn't
available when this was written, it's marked `NOT PROVIDED` — don't guess
past those markers, go look at the actual file.

---

## PART 1 — What This Is (Plain Language)

A self-hosted AI inference service on Google Cloud, built with the security
and delivery controls of a real engineering team around it: a signed image
supply chain, admission control that physically rejects unverified images,
network segmentation, GitOps deployment, and real (not estimated) cost
tracking.

**Input → processing → output:** User sends a prompt over HTTP → request
reaches a vLLM server running Qwen2.5-1.5B-Instruct inside Kubernetes →
vLLM generates a completion → JSON response returned.

**Why it matters:** Getting one AI response to work once is easy. Proving,
continuously, that what's running is what you intended, reachable only by
what should reach it, and deployed through a controlled path instead of
manual `kubectl apply` — that's the actual engineering problem this solves.

---

## PART 2 — Engineering Objective

### Functional Requirements
1. Serve LLM completions over HTTP via vLLM.
2. Build, scan, SBOM, and sign container images on every push.
3. Reject unsigned/unverified images at admission time.
4. Deploy via GitOps, reconciled continuously from git.
5. Deny all pod-to-pod traffic by default; explicitly allow only intended paths.
6. Attribute real infrastructure cost per namespace.

### Non-Functional Requirements
- **Security:** signed chain, admission enforcement, no static cloud credentials anywhere.
- **Reproducibility:** full destroy/rebuild via Terraform.
- **Auditability:** every claim traceable to a real command's real output.

### Constraint (real, external — not a design choice)
GPU provisioning blocked by a project/account-level GCP quota ceiling:
`GPUS_ALL_REGIONS = 0.0`. Full investigation in ADR-GPU-001 below.

### Known Limitations (stated up front, not discovered later)
- No auth layer in front of the inference endpoint.
- No GPU inference ever actually run.
- Load testing performed: five sequential requests only — no true
  concurrency, no saturation point measured.

---

## PART 3 — System at a Glance

### 3.1 Architecture

GitHub (source)
→ GitHub Actions CI (WIF auth → docker build → Trivy scan → Syft SBOM → Cosign sign)
→ Artifact Registry (signed image)
→ ArgoCD (watches GitHub repo, reconciles cluster state)
→ GKE cluster
→ Kyverno (verifies Cosign signature before any pod is admitted)
→ NetworkPolicy (default-deny + explicit allow)
→ vLLM Deployment on dedicated cpu-inference-pool → Service → Ingress
→ OpenCost + Prometheus (read-only cost observer)


### 3.2 Component Responsibilities

| Component | What it is | Why it exists | Depends on |
|---|---|---|---|
| `google_compute_network.main` | Custom VPC, `auto_create_subnetworks = false` | Explicit subnets/routes so network boundaries can be tested, not inherited from GCP defaults | `google_project_service.required` |
| `google_container_cluster.primary` | GKE cluster, zonal control plane | Hosts everything | VPC, subnet |
| `google_container_node_pool.cpu_inference` | Dedicated pool, `e2-standard-4`, 60GB disk | Isolated from platform tooling so inference never competes for resources; sized to avoid two real prior incidents (insufficient memory, DiskPressure) | cluster, `gke_nodes` SA |
| `google_container_node_pool.gpu` (referenced, file NOT PROVIDED) | GPU pool, autoscaling min=0 | Original design target; kept at zero nodes due to quota blocker | cluster |
| `google_service_account.gke_nodes` | Node-level identity | Deliberately minimal — logging/metrics/image-pull only | — |
| `google_service_account.vllm_app` | App-level identity | Kept separate from node identity — nodes and workloads should never share one | — |
| `google_iam_workload_identity_pool.github` | WIF pool | GitHub Actions authenticates via short-lived OIDC; also required because an org policy blocks static key creation entirely | `google_project_service.required` |
| Kyverno | Admission controller | Verifies Cosign signatures; fails closed if it can't pull the image to check | `kyverno_workload_identity` binding + `kyverno_artifact_reader` IAM |
| ArgoCD | GitOps controller | Cluster state reconciled from git, not manual apply | GitHub repo access |
| OpenCost + Prometheus | Cost attribution | Real per-namespace cost via Cloud Billing API | Cloud Billing API enabled |

### 3.3 Data Flow

User → HTTP → Service (vllm-inference-cpu-svc:8000)
→ Pod (vllm-inference-cpu, nodeSelector: pool=cpu-inference)
→ vLLM process (python3 -m vllm.entrypoints.openai.api_server)
→ Qwen2.5-1.5B-Instruct inference, bfloat16, --enforce-eager
→ JSON completion → back to user

NOT PROVIDED: any validation/auth layer between the Service and vLLM — none exists.

---

## PART 4 — Dependency Graph (why this exact order)

VPC + subnets
↓ cluster needs network to attach to
GKE cluster + node pools
↓ CI needs a deploy target and an identity
Workload Identity Federation + service accounts
↓ an image must exist before anything can verify its signature
CI pipeline: build → Trivy scan → Syft SBOM → Cosign sign
↓ enforcement needs a real signed image to test against, both directions
Kyverno install + signature policy + image-pull IAM binding
↓ GitOps needs working manifests in git before it can reconcile them
ArgoCD install + scoped Application
↓ cost attribution needs a running workload to attribute cost to
OpenCost + Prometheus

Skipping any arrow breaks the next step in a specific, observed way — e.g.
skip the `kyverno_artifact_reader` IAM binding and Kyverno verification
"fails closed (denies everything) rather than actually checking signatures"
— which *looks* like security working, but isn't actually verifying anything.

---

## PART 5 — Build Steps (real source, in dependency order)

### STEP 1 — Enable required GCP APIs
**File:** `terraform/environments/dev/apis.tf` — **NOT PROVIDED** (not shared
this session). You will need: `compute.googleapis.com`,
`container.googleapis.com`, `iam.googleapis.com`, `iamcredentials.googleapis.com`,
`artifactregistry.googleapis.com`, `secretmanager.googleapis.com`,
`logging.googleapis.com`, `monitoring.googleapis.com`,
`cloudresourcemanager.googleapis.com`, `billingbudgets.googleapis.com`
(these were confirmed present via `terraform state list` output seen this
session, but the exact `.tf` resource block wasn't shared — write it as a
`google_project_service` resource `for_each` over this list).

### STEP 2 — Custom VPC and subnet
**File:** `terraform/environments/dev/network.tf` (real, full content):
```hcl
# Custom VPC - explicit, not the GCP default network.
# Every subnet and route here exists because we defined it,
# which is what lets us explain and test network boundaries later.
resource "google_compute_network" "main" {
  name                    = "project7-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}

# Single subnet, VPC-native (alias IP ranges), sized generously
# since IP space is free and running out mid-build is a real risk.
resource "google_compute_subnetwork" "main" {
  name          = "project7-subnet"
  ip_cidr_range = "10.10.0.0/20" # ~4,096 node IPs
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16" # ~65,536 pod IPs
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20" # ~4,096 service IPs
  }
  private_ip_google_access = true
}
```
**Why:** Explicit networking over GCP's auto-mode specifically so network
boundaries can be reasoned about and tested later (this directly enables the
NetworkPolicy work in Step 9).
**Verify:** `gcloud compute networks list --project=$PROJECT_ID` shows
`project7-vpc`, `SUBNET_MODE: CUSTOM`.

### STEP 3 — GKE cluster + system node pool
**File:** `terraform/environments/dev/gke.tf` — **NOT PROVIDED** (not shared
this session). Confirmed real from live `gcloud container clusters describe`
output seen this session: zonal control plane in `us-central1-a`, cluster
name `project7-cluster`. You will need a `google_container_cluster.primary`
resource plus a `system-pool` node pool (`e2-standard-2` confirmed via
`gcloud container node-pools list` output, disk 30GB).

### STEP 4 — Node + app service accounts, least privilege
**File:** `terraform/environments/dev/iam.tf` (real, full content):
```hcl
# Service account the GKE worker nodes run as.
# Deliberately minimal - logging, metrics, and image pulls only.
# This is NOT for application-level permissions; that's what
# Workload Identity + per-workload service accounts are for.
resource "google_service_account" "gke_nodes" {
  account_id   = "project7-gke-nodes"
  display_name = "Project 7 GKE Node Service Account"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_service_account" "ci_pipeline" {
  account_id   = "project7-ci-pipeline"
  display_name = "CI Pipeline Service Account"
}

resource "google_project_iam_member" "ci_pipeline_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci_pipeline.email}"
}

# Kyverno needs to PULL images to verify their Cosign signatures.
# Without this, verification fails closed (denies everything) rather
# than actually checking signatures - which is safe, but not a true
# signature-verification test.
resource "google_project_iam_member" "kyverno_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:project7-gke-nodes@velrite-tf-test.iam.gserviceaccount.com"
}

# Kyverno's admission-controller pod needs to pull images from
# Artifact Registry to verify Cosign signatures. Granting IAM to
# the node-level service account does NOT flow through to pods -
# each pod needs its own explicit Workload Identity binding.
resource "google_service_account_iam_member" "kyverno_workload_identity" {
  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kyverno/kyverno-admission-controller]"
}
```
**Why two separate service accounts (nodes vs CI):** Explicit design —
node-level and CI-level permissions must never be conflated. A compromised
node shouldn't inherit CI's `artifactregistry.writer` ability to push images.
**Underrated detail:** Granting IAM to a *node-level* service account does
NOT automatically flow through to pods running on that node — each workload
needing its own GCP permissions needs its own explicit Workload Identity
binding (seen directly in the Kyverno binding above). This is a genuinely
easy mistake: assuming node IAM covers pod IAM.
**Verify:** `gcloud iam service-accounts list --project=$PROJECT_ID` shows
both `project7-gke-nodes@...` and `project7-ci-pipeline@...`.

### STEP 5 — App-level identity + Secret Manager (proven mechanism)
**File:** `terraform/environments/dev/secrets-workload-identity.tf` (real, full content):
```hcl
# Dedicated identity for the inference application itself -
# separate from gke_nodes (which is for the node/kubelet layer).
# App workloads and nodes should never share an identity.
resource "google_service_account" "vllm_app" {
  account_id   = "vllm-app-sa"
  display_name = "vLLM Application Service Account"
}

# Least privilege: this identity can ONLY read secrets, nothing else.
resource "google_project_iam_member" "vllm_app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vllm_app.email}"
}

# Workload Identity binding: allows the Kubernetes service account
# "vllm-app-ksa" in the "default" namespace to impersonate the GCP
# service account above. This is what removes the need for any
# JSON key file to ever exist.
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.vllm_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/vllm-app-ksa]"
}

# A real (but dummy/test) secret to prove the mechanism end-to-end.
resource "google_secret_manager_secret" "test_api_key" {
  secret_id = "vllm-test-api-key"
  replication { auto {} }
  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "test_api_key_value" {
  secret      = google_secret_manager_secret.test_api_key.id
  secret_data = "dummy-test-value-not-a-real-secret"
}
```
**Why a dummy secret:** Proves the plumbing (KSA → GSA impersonation →
Secret Manager read) works end-to-end without risking a real credential
during testing.
**Verify:** From inside a pod using the `vllm-app-ksa` KSA:
`gcloud secrets versions access latest --secret=vllm-test-api-key` should
return `dummy-test-value-not-a-real-secret` with no key file anywhere on disk.

### STEP 6 — Workload Identity Federation for CI (no static keys)
**File:** `terraform/environments/dev/workload-identity-federation.tf` (real, full content):
```hcl
# Workload Identity Federation lets GitHub Actions authenticate to GCP
# using short-lived OIDC tokens instead of a long-lived JSON key.
# This is the correct pattern - and it sidesteps the org policy that
# blocks static service-account key creation entirely, since no key
# file is ever created.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions CI"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Restrict to ONLY this specific repo - least privilege
  attribute_condition = "assertion.repository == \"velrite/project7-ai-inference-platform\""
}

resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.ci_pipeline.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/velrite/project7-ai-inference-platform"
}
```
**Underrated detail:** `attribute_condition` is the actual security boundary
— without this one line, trust extends to any repo under any account claiming
to be this CI pipeline, not just this specific repository.
**Real failure encountered:** After `terraform destroy`, this pool/provider
go into GCP soft-delete rather than disappearing. A plain `terraform apply`
returns `Error 409: Requested entity already exists`. Fix:
```bash
gcloud iam workload-identity-pools describe github-actions-pool --location=global --project=$PROJECT_ID --format="yaml(state,name)"
# if state: DELETED —
gcloud iam workload-identity-pools undelete github-actions-pool --location=global --project=$PROJECT_ID
terraform import google_iam_workload_identity_pool.github "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/github-actions-pool"
# repeat the same pattern for the provider:
gcloud iam workload-identity-pools providers undelete github-provider --workload-identity-pool=github-actions-pool --location=global --project=$PROJECT_ID
terraform import google_iam_workload_identity_pool_provider.github "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"
```

### STEP 7 — Dedicated CPU inference node pool
**File:** `terraform/environments/dev/cpu-inference-pool.tf` (real, full content):
```hcl
# Dedicated CPU inference node pool - separate from system-pool so
# platform tooling (Kyverno, Argo CD, NGINX) never competes with the
# inference workload for resources. Sized from real prior failures:
# e2-standard-4 (4 vCPU/16GB) and 60GB disk avoid both the
# Insufficient-memory and DiskPressure incidents recorded in ADR-005.
resource "google_container_node_pool" "cpu_inference" {
  name     = "cpu-inference-pool"
  cluster  = google_container_cluster.primary.name
  location = var.zone

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  node_config {
    machine_type    = "e2-standard-4"
    disk_size_gb    = 60
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = { pool = "cpu-inference" }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
```
**File:** `terraform/environments/dev/gpu-node-pool.tf` — **NOT PROVIDED**
(not shared this session). Confirmed real from live `gcloud` output:
`nvidia-tesla-v100`, `acceleratorCount: 1`, `autoscaling.minNodeCount: 0`,
`maxNodeCount: 1`. Write analogously to the CPU pool above, with an
`accelerator { type = "nvidia-tesla-v100", count = 1 }` block inside
`node_config` and appropriate taints/tolerations so only GPU-tolerant pods
schedule there.
**Why `min_node_count = 0` on both:** Zero nodes = zero compute cost while
idle — confirmed directly via `gcloud compute instances list` showing no GPU
instance present for most of the project's history.
**Underrated detail:** `labels = { pool = "cpu-inference" }` here must
exactly match `nodeSelector: pool: cpu-inference` in the Deployment (Step 10)
— if these two independently-maintained strings ever drift, the pod stays
`Pending` forever with no obvious error.
**Verify:**
```bash
gcloud container node-pools list --cluster=project7-cluster --zone=$ZONE --project=$PROJECT_ID
```

### STEP 8 — Artifact Registry
**File:** `terraform/environments/dev/artifact-registry.tf` — **NOT PROVIDED**
(not shared, but confirmed real and in use: repository
`us-central1-docker.pkg.dev/velrite-tf-test/project7-inference`). Write a
`google_artifact_registry_repository` resource, `format = "DOCKER"`,
`location = var.region`.

### STEP 9 — Network segmentation (default-deny)
**Files:** `k8s/network-policies/default-deny.yaml`, `allow-granted-only.yaml`
— **NOT PROVIDED exact content**, but confirmed real and live via
`kubectl get networkpolicy -A`:

NAMESPACE NAME POD-SELECTOR
default default-deny-all <none>
default allow-granted-to-target app=target-app

Write `default-deny-all` as a `NetworkPolicy` with empty `podSelector: {}`
and `policyTypes: [Ingress, Egress]` (blocks everything by default). Write
`allow-granted-to-target` as a second policy selecting `app: target-app`
with an explicit `ingress.from` rule for the intended caller only.
**Verify (real test, proven this project):** deploy an unrelated pod without
the `app: target-app` label and confirm it cannot reach the protected
Service — a genuine `wget` timeout/connection-refused confirms enforcement,
not just the policy objects existing.

### STEP 10 — Dockerfile
**File:** `app/Dockerfile` (real, full content):
```dockerfile
# Minimal vLLM inference runtime image.
# We do NOT bake the model into the image - models are large (15GB+)
# and baking them in would make every rebuild slow and bloat the
# image registry. Model is pulled at container start instead.
FROM vllm/vllm-openai:latest

WORKDIR /app

# vLLM's OpenAI-compatible server port
EXPOSE 8000

ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
```
**Why the model isn't baked in:** Explicit trade-off — smaller/faster image
builds at the cost of a cold-start model download on first pod start.

### STEP 11 — vLLM Deployment manifest
**File:** `k8s/vllm-deployment-cpu.yaml` (real, full content):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-inference-cpu
  labels:
    app: vllm-inference-cpu
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-inference-cpu
  template:
    metadata:
      labels:
        app: vllm-inference-cpu
    spec:
      nodeSelector:
        pool: cpu-inference
      volumes:
        - name: dshm
          emptyDir:
            medium: Memory
            sizeLimit: 2Gi
      containers:
        - name: vllm
          image: public.ecr.aws/q9t5s3a7/vllm-cpu-release-repo:latest
          env:
            - name: VLLM_CPU_KVCACHE_SPACE
              value: "4"
            - name: VLLM_ENABLE_V1_MULTIPROCESSING
              value: "0"
          args:
            - "--model=Qwen/Qwen2.5-1.5B-Instruct"
            - "--dtype=bfloat16"
            - "--max-model-len=4096"
            - "--enforce-eager"
          ports:
            - containerPort: 8000
          volumeMounts:
            - name: dshm
              mountPath: /dev/shm
          resources:
            requests:
              cpu: "2500m"
              memory: "8Gi"
            limits:
              cpu: "3500m"
              memory: "12Gi"
          startupProbe:
            httpGet: { path: /health, port: 8000 }
            failureThreshold: 90
            periodSeconds: 10
          readinessProbe:
            httpGet: { path: /health, port: 8000 }
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /health, port: 8000 }
            periodSeconds: 15
```
**Why `VLLM_ENABLE_V1_MULTIPROCESSING=0` + `--enforce-eager`:** Fixes a real,
encountered CPU startup deadlock (commit `015b825`). vLLM's V1 engine
defaults to a multiprocessing path that hangs in this CPU environment;
disabling it and forcing eager execution resolved it. **If you skip this:**
the pod will hang indefinitely at startup with no crash and no clear error —
this is the single most important undocumented gotcha in this entire build.
**Why `emptyDir: medium: Memory` for `/dev/shm`:** Default container shm
(64MB) is too small for vLLM's CPU tensor operations and fails silently.
**Why three separate probes:** `startupProbe` (up to 15 min via
`failureThreshold: 90 × periodSeconds: 10`) tolerates genuinely long model
load without Kubernetes killing the pod as unhealthy; `readinessProbe` and
`livenessProbe` take over afterward with much tighter loops.
**Verify:**
```bash
kubectl apply -f k8s/vllm-deployment-cpu.yaml
kubectl wait --for=condition=Ready pod -l app=vllm-inference-cpu --timeout=600s
kubectl port-forward svc/vllm-inference-cpu-svc 8000:8000 &
curl localhost:8000/v1/completions -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen2.5-1.5B-Instruct","prompt":"Say hello in one word.","max_tokens":5}'
```
Also write `k8s/vllm-service-cpu.yaml` (ClusterIP Service, port 8000) and
`k8s/ingress/vllm-cpu-ingress.yaml` (NGINX ingress, rate limiting and request
size limits confirmed present via README's own status table — exact YAML
NOT PROVIDED).

### STEP 12 — CI pipeline
**File:** `.github/workflows/ci-security.yml` (real, full content — reconstructed from the fetched log, key structure confirmed):
```yaml
name: CI Security Pipeline
on:
  push: { branches: [main, master] }
  pull_request: { branches: [main, master] }
env:
  REGISTRY: us-central1-docker.pkg.dev
  IMAGE_NAME: velrite-tf-test/project7-inference/vllm-inference
permissions:
  contents: read
  id-token: write
jobs:
  build-scan-sbom-sign:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/362285503795/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider'
          service_account: 'project7-ci-pipeline@velrite-tf-test.iam.gserviceaccount.com'
      - run: gcloud auth configure-docker ${{ env.REGISTRY }} --quiet
      - run: docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} ./app
      - run: docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
      - uses: aquasecurity/trivy-action@v0.36.0
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          severity: CRITICAL
          exit-code: 1
      - uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: spdx-json
          output-file: sbom.spdx.json
      - uses: actions/upload-artifact@v4
        with: { name: sbom, path: sbom.spdx.json }
      - uses: sigstore/cosign-installer@v3
      - env:
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
        run: |
          echo "${{ secrets.COSIGN_PRIVATE_KEY }}" > cosign.key
          cosign sign --key cosign.key --yes ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          rm -f cosign.key
```
**Why `exit-code: 1` on Trivy with `severity: CRITICAL`:** Any new CRITICAL
CVE blocks the pipeline before SBOM/signing ever run — a real failure mode
hit mid-project (two new CRITICAL CVEs in `linux-libc-dev` landed
undocumented). Fix: add the CVE IDs to `.trivyignore` with a justification
comment once confirmed unexploitable for this workload, same pattern as the
existing 4 exceptions.
**File:** `.trivyignore` (real content):
CVE-2025-37777: linux-libc-dev headers only, ksmbd component not used
by this workload. See docs/security-exceptions.md for full justification.

CVE-2025-37777
CVE-2026-53398
CVE-2026-64535
CVE-2026-64564

**Secrets needed in GitHub repo settings:** `COSIGN_PASSWORD`,
`COSIGN_PRIVATE_KEY`. Generate the key pair with
`cosign generate-key-pair` — commit only `cosign.pub` (public key, safe to
share), never `cosign.key` (add to `.gitignore`).
**Verify:** `gh run watch <run-id> --exit-status` should end with all steps
`✓` and `completed with 'success'`.

### STEP 13 — Kyverno admission enforcement
**File:** `k8s/admission/require-signed-images.yaml` (real, full content):
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "us-central1-docker.pkg.dev/velrite-tf-test/project7-inference/*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEOCbfjVwzPuh5fR4ScJhxn8FixoWV
                      //iwfnSwlqhBhiPWTvCVIP22EwUyTrWO45JBE3WuU0HMHL+l6HkavIp7iQ==
                      -----END PUBLIC KEY-----
```
**Install:**
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
kubectl create namespace kyverno --dry-run=client -o yaml | kubectl apply -f -
helm install kyverno kyverno/kyverno --namespace kyverno
kubectl rollout status deployment kyverno-admission-controller -n kyverno --timeout=180s
kubectl annotate serviceaccount kyverno-admission-controller -n kyverno \
  iam.gke.io/gcp-service-account=project7-gke-nodes@$PROJECT_ID.iam.gserviceaccount.com --overwrite
kubectl apply -f k8s/admission/require-signed-images.yaml
```
**Underrated detail:** `imageReferences` is scoped to one specific registry
path on purpose — a pod using an out-of-scope image (e.g. `nginx:latest`) is
correctly *ignored* by this policy, which can be mistaken for broken
enforcement if you don't check scope first.
**Verify, both directions (do not skip either):**
```bash
# Should be DENIED
kubectl run test-deny --image=us-central1-docker.pkg.dev/velrite-tf-test/project7-inference/vllm-inference:nonexistent-tag --restart=Never
# Should be CREATED (use your real signed SHA tag)
kubectl run test-allow --image=us-central1-docker.pkg.dev/velrite-tf-test/project7-inference/vllm-inference:$(git rev-parse HEAD) --restart=Never
kubectl delete pod test-deny test-allow --ignore-not-found=true
```

### STEP 14 — ArgoCD GitOps
**Install:**
```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
kubectl rollout status deployment argocd-server -n argocd --timeout=180s
```
**Application (scoped — do not sync the whole folder blindly):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: project7-inference
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/velrite/project7-ai-inference-platform.git
    targetRevision: master
    path: k8s
    directory:
      exclude: vllm-deployment.yaml   # abandoned GPU manifest - real lesson below
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated: { prune: false, selfHeal: false }
```
**Real lesson (actually hit this):** An unscoped sync of all of `k8s/`
deployed an abandoned GPU-targeted manifest (`vllm-deployment.yaml`)
alongside the real CPU one — it created a second, permanently-`Pending`
deployment because no GPU nodes exist. `directory.exclude` fixes it. If you
don't have a leftover manifest like this, you won't hit this — but if you
do, this is exactly why.
**Verify:**
```bash
kubectl get application project7-inference -n argocd
# Expect: SYNC STATUS: Synced, HEALTH STATUS: Healthy
echo "=== same commit, three systems ==="
git rev-parse HEAD
kubectl get application project7-inference -n argocd -o jsonpath='{.status.sync.revision}'
```

### STEP 15 — Cost attribution
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add opencost https://opencost.github.io/opencost-helm-chart --force-update
kubectl create namespace prometheus-system --dry-run=client -o yaml | kubectl apply -f -
helm install prometheus prometheus-community/prometheus --namespace prometheus-system \
  --set server.persistentVolume.enabled=false --set alertmanager.enabled=false
kubectl create namespace opencost --dry-run=client -o yaml | kubectl apply -f -
helm install opencost opencost/opencost --namespace opencost
gcloud services enable cloudbilling.googleapis.com --project=$PROJECT_ID
# create a Cloud Billing API key, store as k8s secret opencost-gcp-key, then:
kubectl port-forward -n opencost svc/opencost 9003:9003 &
curl "localhost:9003/allocation/compute?window=7d&aggregate=namespace"
```
**Real result obtained this way (14-minute sample, not a stable monthly figure):**

| Namespace | CPU cost | RAM cost | Total |
|---|---|---|---|
| `default` (vLLM) | $0.01814 | $0.00778 | $0.02591 |
| `kube-system` | $0.01481 | $0.00183 | $0.01664 |
| **Total (measured window)** | | | **$0.04374** |

**Underrated detail:** Prometheus deployed with `persistentVolume.enabled=
false` — cost history resets to near-zero after any pod restart. For a real
deployment, add a PVC.

---

## PART 6 — Evolution of the System (real changes, in order)

| Original approach | Problem discovered | Change made |
|---|---|---|
| GPU-targeted deployment | `GPUS_ALL_REGIONS=0.0` account-level quota, confirmed across 5 regions + a fresh project | Rebuilt on CPU node pool, same vLLM base, no rewrite |
| vLLM default V1 multiprocessing | CPU startup deadlock | `VLLM_ENABLE_V1_MULTIPROCESSING=0` + `--enforce-eager` |
| Manual `kubectl apply` of all manifests | Risk of drift / ArgoCD fighting manual changes | ArgoCD Application reconciling from git |
| ArgoCD syncing all of `k8s/` | Deployed an abandoned GPU manifest, stuck `Pending` | `directory.exclude` scoping |
| `.trivyignore` with 4 exceptions | 2 new undocumented CRITICAL CVEs landed, blocked CI | Added 2 new, justified exceptions, same pattern |

---

## PART 9 — Architecture Decision Records

### ADR-GPU-001: GPU Provisioning Blocked by `GPUS_ALL_REGIONS` Quota
**Status:** Blocked — external dependency (Google Cloud Support manual review).

**Context:** Full GPU infrastructure was built and verified — node pool
Terraform, taints/tolerations, V100 quota confirmed available, GKE
scheduling configuration correct.

**What was tried:** L4 (quota initially 0, later resolved, still blocked),
T4 (same pattern), P100 (ruled out, unavailable in zone), V100 (individual
quota confirmed 1.0, zone stock confirmed, MIG creation blocked), 5 regions
tested (same result), a fresh GCP project under the same billing account
(same result).

**Root cause:** Project-wide `GPUS_ALL_REGIONS` quota = 0.0, confirmed via
direct MIG error logs ("Quota 'GPUS_ALL_REGIONS' exceeded. Limit: 0.0
globally.") and an identical result on a brand-new project under the same
account — meaning this ceiling is tied to the account/billing identity, not
any specific project or region.

**Why self-service resolution wasn't possible:** GCP Console quota-edit form
explicitly rejected increase requests; Cloud Support billing confirmed it's
outside their scope, redirected to manual review.

**Decision:** Escalated with precise, evidence-backed findings. Continued
all GPU-independent work rather than blocking on one external dependency.

**Lesson:** "A single external platform dependency (cloud provider quota
approval) can block one specific capability without blocking a project's
overall engineering demonstration. Documenting the blocker precisely —
including everything ruled out and why — is itself evidence of methodical
troubleshooting, not a gap in the work."

### ADR-002: GitOps Scope Exclusion
**Context:** Unscoped ArgoCD sync deployed an abandoned GPU manifest,
creating a stuck `Pending` deployment.
**Decision:** `directory.exclude` in the Application spec.
**Lesson:** A tool doing exactly what it's configured to do is not the same
as doing what you meant — GitOps needs explicit scope, not just "sync the
folder."

---

## PART 13 — Reliability and Failure Modes (real test data)

### Pod-kill recovery (real, from `docs/07-reliability/`)
The running pod was force-deleted while healthy. Kubernetes rescheduled a
replacement automatically. **Real finding:** the new pod reached `Running`
within seconds but did **not** report `Ready` until several minutes later —
a first readiness check genuinely failed (connection-refused) because the
model was still loading. Recovery time for a stateful ML-serving pod must
include full model-reload time, not just container-restart time. Once
`kubectl wait` confirmed genuine readiness, a real inference request against
the same Service succeeded — correct routing to the new pod, zero manual
intervention.

### Load test — five real, unfiltered sequential requests
| Request | Result |
|---|---|
| 1 | Timed out at 60s |
| 2 | Timed out at 60s |
| 3 | Succeeded, 43.8s |
| 4 | Succeeded, 9.7s |
| 5 | Succeeded, 9.3s |

**Interpretation (from the real doc):** Clear cold-to-warm pattern — the
first two requests likely triggered one-time kernel compilation/memory-layout
work inside vLLM's CPU path. Once paid, latency stabilized ~9–10s for a
~20-token completion on CPU. "Should not be read as representative of
expected GPU latency, which would be materially faster."
**Stated limitation:** True concurrent load, a saturation point, and
TTFT/TPOT as separate metrics were not measured — five sequential requests
only.

| Failure | Detection | Recovery |
|---|---|---|
| `terraform destroy` run | N/A — deliberate | `terraform apply`; WIF needed soft-delete recovery (Step 6) |
| CI CVE scan failure | Red run | `.trivyignore` exception added |
| Unsigned image deployed | Kyverno admission webhook | Pod creation rejected — no manual action needed |
| vLLM CPU deadlock | Pod stuck, never Ready | `VLLM_ENABLE_V1_MULTIPROCESSING=0` + `--enforce-eager` |
| GitOps scope mismatch | `Pending` pod | `directory.exclude` |

---

## PART 17 — Cost Engineering

Real spend (`docs/08-finops/cost-per-inference.md`, GCP Billing Reports Aug
1–19 2026): $27.50 total usage cost, fully offset by free-trial credit ($0
net billed), plus a one-time $10 account-reactivation charge (separate,
account-level, not usage). ~10–15 real inference requests served across all
testing → "~$1.83 per inference request" — explicitly stated in the source
doc as a methodology demonstration using fixed-cost-dominated small-sample
data, **not representative of production unit economics**.
**Cost controls:** deliberate destroy/rebuild cycle between sessions
(`scripts/teardown.sh`); GPU pool autoscaling min=0.
**Stated gap:** no programmatic hard billing cap implemented (identified,
not built).

---

## PART 20 — Repository Structure

project7-ai-inference-platform/
├── app/
│ └── Dockerfile # vLLM image, model NOT baked in
├── terraform/environments/dev/
│ ├── apis.tf # NOT PROVIDED - required APIs
│ ├── network.tf # custom VPC + subnet
│ ├── gke.tf # NOT PROVIDED - cluster + system pool
│ ├── iam.tf # node + CI service accounts
│ ├── secrets-workload-identity.tf # vllm_app SA + Secret Manager
│ ├── workload-identity-federation.tf
│ ├── cpu-inference-pool.tf
│ ├── gpu-node-pool.tf # NOT PROVIDED - V100, min=0
│ ├── artifact-registry.tf # NOT PROVIDED
│ ├── backend.tf, variables.tf, terraform.tfvars # NOT PROVIDED
├── k8s/
│ ├── admission/require-signed-images.yaml
│ ├── network-policies/ # NOT PROVIDED exact YAML, real objects confirmed
│ ├── workload-identity/ksa.yaml # NOT PROVIDED
│ ├── vllm-deployment-cpu.yaml
│ ├── vllm-service-cpu.yaml # NOT PROVIDED exact YAML
│ ├── ingress/ # NOT PROVIDED exact YAML
│ └── observability/vllm-podmonitoring.yaml # NOT PROVIDED exact YAML
├── .github/workflows/ci-security.yml
├── .cosign/cosign.pub
├── .trivyignore
├── scripts/startup.sh, teardown.sh
└── docs/ # ADRs, evidence, runbooks


---

## PART 22 — If I Had to Rebuild This From Scratch (condensed order)

1. Enable required GCP APIs (Step 1).
2. Terraform: VPC/subnet → GKE cluster + system pool → node/CI/app service
   accounts → Secret Manager → WIF → CPU + GPU node pools → Artifact
   Registry. `terraform apply`, verify with `gcloud container clusters list`.
3. Write and push the Dockerfile + CI workflow. Generate a Cosign key pair,
   store `COSIGN_PASSWORD`/`COSIGN_PRIVATE_KEY` as GitHub secrets, commit
   only `cosign.pub`. Push, verify with `gh run watch <id> --exit-status`.
4. Write and apply the vLLM Deployment/Service/Ingress manifests on the CPU
   pool. Verify with a real `curl` to `/v1/completions`.
5. Install Kyverno, annotate its KSA for Workload Identity, apply the
   signature policy. Verify with the deny/allow pod test pair (Step 13).
6. Install ArgoCD, create the scoped Application. Verify `Synced`/`Healthy`
   and that the synced revision matches `git rev-parse HEAD`.
7. Apply NetworkPolicy. Verify with an ephemeral pod that should be denied.
8. Deploy OpenCost + Prometheus. Verify with a real cost pull.
9. Capture evidence for each step as you go — screenshots of real command
   output, not after-the-fact recreations.

---

## PART 24 — Things That Look Small but Matter

| Detail | Why it looks small | Why it actually matters |
|---|---|---|
| `attribute_condition` on the WIF provider | One line of HCL | The actual security boundary on who can claim this CI identity |
| `labels = { pool = "cpu-inference" }` ↔ `nodeSelector` | A string match | Drift between these two = pod stuck `Pending` forever, no clear error |
| `VLLM_ENABLE_V1_MULTIPROCESSING=0` | One env var | Fixes a real CPU startup deadlock — without it, silent indefinite hang |
| `emptyDir: medium: Memory` for `/dev/shm` | A volume mount | Default container shm silently breaks vLLM CPU tensor ops |
| `kyverno_artifact_reader` IAM binding | A read permission | Without it, verification fails closed — looks like security working, isn't actually checking anything |
| `validationFailureAction: Enforce` vs `Audit` | One word | The entire difference between blocking and only logging |
| GCP WIF soft-delete | "Just a 409 error" | Terraform alone can't recover it — needs explicit `undelete` + `import` |
| ArgoCD sync scope (`directory.exclude`) | "Just a folder path" | Unscoped sync deploys everything in the folder, including abandoned manifests |

---

## PART 26 — Technical Debt Register

| Debt | Why it exists | Recommended change |
|---|---|---|
| Deprecated `kyverno.io/v1 ClusterPolicy` API | Chart default, flagged live by `kubectl` | Migrate to `ImageValidatingPolicy` |
| Abandoned GPU manifest left in `k8s/`, excluded by filename | Historical record | Move to an `archive/` folder instead |
| No input validation in front of vLLM | Narrow project scope | Add a validation/rate-limit layer |
| No persistent Prometheus storage | Cost control during dev | Add a PVC for real cost trending |

---

## PART 28 — Interview Defense

**"Why two separate GCP service accounts for nodes vs. the app?"**
Node-level and application-level permissions must never be conflated — the
node identity can log/emit-metrics/pull-images; the app identity can *only*
read secrets. A compromised pod inherits the narrower scope.

**"Walk me through pod recovery."**
Force-deleted a healthy pod. Kubernetes rescheduled it within seconds, but
it genuinely wasn't `Ready` for several minutes, because readiness means
the model finished loading, not just that the container started — my first
verification attempt failed exactly because I checked too early.

**"Why WIF instead of a service account key?"**
Architecturally correct (short-lived OIDC, nothing to leak) *and* a hard
constraint — the org policy on this account blocks static key creation
outright.

**"Biggest known gap?"**
No auth in front of the inference endpoint; load testing is five sequential
requests, not true concurrency — both logged in my own docs, not found by
a reviewer.

---

## PART 30 — Engineering Summary

**What I built:** A GKE-based LLM inference platform with a signed, scanned,
admission-enforced delivery path, GitOps deployment, and real cost
attribution — including real incident recovery (soft-deleted IAM resources,
a broken CI pipeline, a GitOps scoping mistake) documented with the same
rigor as what worked the first time.

**Core engineering problem:** Proving what's running in the cluster is what
was actually intended — demonstrated with live, both-directions tests.

**Major trade-off:** CPU inference instead of GPU — a real, externally
imposed account-level quota ceiling, investigated exhaustively and escalated
through the correct channel rather than hidden.

**What's explicitly not claimed:** No production traffic, no real users, no
GPU numbers, no concurrent-load saturation point.
