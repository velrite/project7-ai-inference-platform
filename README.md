# Project 7 — Production AI Inference Platform

**Olamide (Velrite)** — GitHub: [velrite](https://github.com/velrite)

## What this is

A GKE-based inference platform for an open-source LLM, engineered for
production operation: a signed software supply chain, admission
control that rejects unverified images, network segmentation, GitOps
deployment, and cost tracking — every control proven with a live test,
not just declared in configuration.

## Current status

The platform was engineered for GPU inference. GPU node provisioning
is blocked by a Google Cloud account-level quota
(`GPUS_ALL_REGIONS = 0.0`), confirmed via direct instance-group error
logs and ruled out across every GPU type, every region, and a
freshly-created project under the same billing account. Full
diagnosis in [05-gpu-constraint-and-cost.md](docs/05-gpu-constraint-and-cost.md).

The entire platform is validated end-to-end on CPU inference
(Qwen2.5-1.5B-Instruct) instead, including live inference, load
testing, pod-failure recovery, and rollback behavior — all with real
measured results, not estimates.

## Architecture

```mermaid
flowchart TD
    Dev[Developer] -->|git push| GitHub[GitHub Repo]
    GitHub -->|triggers| CI[GitHub Actions CI]
    CI -->|WIF auth, no keys| GCP[GCP Workload Identity Federation]
    CI -->|build + push| AR[Artifact Registry]
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
Evidence
Infrastructure (Terraform)
Live, reproducible
01-architecture.md
Signed supply chain
Proven, both directions tested
02-security-and-supply-chain.md
CI/CD pipeline
Fully green
03-delivery-pipeline.md
Live inference
Real responses generated
04-reliability-evidence.md
GPU deployment
Blocked — account-level GCP quota
05-gpu-constraint-and-cost.md
Quick start
cd terraform/environments/dev
terraform init
terraform plan
terraform apply -auto-approve
gcloud container clusters get-credentials project7-cluster --zone us-central1-a --project velrite-tf-test
Teardown:
cd terraform/environments/dev
terraform destroy -auto-approve
Documentation
01-architecture.md — system design, component decisions
02-security-and-supply-chain.md — threat model, proven controls, incident postmortems
03-delivery-pipeline.md — CI/CD, CVE policy, GitOps
04-reliability-evidence.md — load tests, failure tests, the CPU-inference debugging chain
05-gpu-constraint-and-cost.md — the GPU quota constraint, real cost data
