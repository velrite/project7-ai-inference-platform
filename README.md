# Project 7 — Production AI Inference Platform

**Olamide (Velrite)** — GitHub: [velrite](https://github.com/velrite)

## What this is

A GKE-based inference platform for an open-source LLM, engineered for production operation: a signed software supply chain, admission control that rejects unverified images, network segmentation, GitOps deployment, and cost tracking. Every control is proven with a live test, not just declared in configuration.

## Current status

The platform was engineered for GPU inference. GPU node provisioning is blocked by a Google Cloud account-level quota (`GPUS_ALL_REGIONS = 0.0`), confirmed via direct instance-group error logs and ruled out across every GPU type, every region, and a freshly-created project under the same billing account. Full diagnosis in `docs/05-gpu-constraint-and-cost.md`.

The entire platform is validated end-to-end on CPU inference (Qwen2.5-1.5B-Instruct) instead, including live inference, load testing, pod-failure recovery, and rollback behavior — all with real measured results, not estimates.

## Architecture

```mermaid
flowchart TD
    Dev[Developer] -->|git push| GitHub[GitHub Repo]
    GitHub -->|triggers| CI[GitHub Actions CI]
    CI -->|WIF auth, no keys| GCP[GCP Workload Identity Federation]
    CI -->|build and push| AR[Artifact Registry]
    CI -->|scan| Trivy[Trivy]
    CI -->|SBOM| Syft[Syft]
    CI -->|sign| Cosign[Cosign]
    GitHub -->|watched by| ArgoCD[Argo CD]
    ArgoCD -->|auto-sync| GKE[GKE Cluster]
    GKE --> Kyverno[Kyverno Admission Controller]
    GKE --> NGINX[NGINX Ingress]
    Kyverno -->|verifies signature| Pod[vLLM Inference Pod]
    NGINX -->|rate-limited| Pod
    Pod -.->|Workload Identity| SecretManager[GCP Secret Manager]
Status table
Component
Status
Evidence doc
Infrastructure (Terraform)
Live, reproducible
docs/01-architecture.md
Signed supply chain
Proven, both directions tested
docs/02-security-and-supply-chain.md
CI/CD pipeline
Fully green
docs/03-delivery-pipeline.md
Live inference
Real responses generated
docs/04-reliability-evidence.md
GPU deployment
Blocked, account-level GCP quota
docs/05-gpu-constraint-and-cost.md
Quick start
cd terraform/environments/dev
terraform init
terraform plan
terraform apply -auto-approve
gcloud container clusters get-credentials project7-cluster --zone us-central1-a --project velrite-tf-test
Teardown:
cd terraform/environments/dev
terraform destroy -auto-approve
Things to notice before running:
Always run terraform commands from terraform/environments/dev, not the repo root.
Always review a terraform plan output before approving apply or destroy.
After apply, the vLLM pod takes several minutes to become Ready — it is downloading and loading model weights, not stuck.
After destroy, confirm zero cost exposure with gcloud compute instances list and gcloud container clusters list — both should return empty.
Documentation
docs/01-architecture.md — system design, component decisions
docs/02-security-and-supply-chain.md — threat model, proven controls, incident postmortems
docs/03-delivery-pipeline.md — CI/CD, CVE policy, GitOps
docs/04-reliability-evidence.md — load tests, failure tests, the CPU-inference debugging chain
docs/05-gpu-constraint-and-cost.md — the GPU quota constraint, real cost data
