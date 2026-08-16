# Project 7 - Production AI Inference Platform

## Overview
A GKE-based platform engineered to serve an open-source LLM securely,
observably, and reproducibly. This project does not train or fine-tune
models - it engineers the infrastructure layer that makes model
inference production-viable: a signed software supply chain,
enforced admission control, network segmentation, GitOps deployment,
and cost-disciplined infrastructure-as-code.

## Problem
Running an open-source LLM once is easy. Running it as a real service -
safe to expose, provably secure against a tampered image or model
artifact, observable, and cost-controlled - is a materially different
problem. See docs/01-overview/problem-statement.md for the full case.

## Architecture
Full architecture, trust boundaries, and a Mermaid diagram are in
docs/02-architecture/architecture.md. Six Architecture Decision Records,
including a full account of the project's central open issue, are in
docs/02-architecture/architecture-decisions.md.

## Key engineering decisions
GKE Standard, zonal, chosen over Autopilot or a regional cluster for
explicit node-pool control (ADR-001). A custom VPC over GCP's default
network (ADR-002). Workload Identity Federation over service-account
JSON keys for CI, adopted specifically after key creation was blocked
by an org security policy (ADR-004). Full details and rationale for
every decision are in the ADR document linked above.

## Technology stack
Cloud: Google Cloud Platform (GKE, Artifact Registry, Secret Manager,
IAM, Workload Identity Federation).
Infrastructure as Code: Terraform, 100 percent of core resources, zero
manual console provisioning.
CI/CD: GitHub Actions, Trivy, Syft, Cosign.
GitOps: Argo CD.
Admission control: Kyverno.
Ingress: NGINX Ingress Controller.
Intended inference engine: vLLM, serving Qwen2.5-7B-Instruct.

## Reliability
Every reliability claim in this project is backed by a live test or
explicitly marked as not yet performed. Full failure-mode incident
matrix, including root cause and resolution for four real incidents
encountered during the build, is in
docs/07-reliability/failure-modes.md.

## Security
Signed, scanned, admission-enforced container images. Default-deny
network policy. Secret Manager access scoped per-workload through
Kubernetes Workload Identity. Full threat model and control-by-control
detail in docs/05-security/.

## Observability
Not yet implemented. This is stated plainly rather than described
aspirationally - see Limitations below.

## CI/CD
Full pipeline: build, push to Artifact Registry, Trivy scan, SBOM
generation, Cosign signing, authenticated via Workload Identity
Federation with no static credentials anywhere in the pipeline.
Details in docs/04-delivery/ci-cd.md.

## Performance
Not yet measured. Blocked on GPU node provisioning - see ADR-006.
Stated plainly rather than estimated.

## Cost
Built entirely within a $300 GCP free-trial credit ceiling. Cost
decisions and discipline documented in docs/08-finops/cost-model.md.

## Failure testing
Four real incidents, each independently detected, root-caused, and
resolved: NetworkPolicy silent non-enforcement, three-stage node pool
resource starvation, Kyverno signature verification failing closed due
to a missing identity binding, and an unresolved external GPU quota
block. Full detail in docs/07-reliability/failure-modes.md.

## Repository structure
app/ - vLLM container definition.
terraform/ - all infrastructure as code.
k8s/ - Kubernetes manifests, GitOps-managed by Argo CD.
scripts/ - model integrity verification.
.github/workflows/ - CI/CD pipeline definition.
docs/ - complete engineering documentation, organized by topic.

## Quick start
Prerequisites: a GCP project with billing enabled, gcloud and terraform
installed, a GitHub repository with Actions enabled.
Clone this repository. Configure terraform/environments/dev/
terraform.tfvars from the provided .example file. Run terraform init,
terraform plan, and review the plan before terraform apply. Connect
kubectl with gcloud container clusters get-credentials. Apply the
Kubernetes manifests under k8s/, or connect Argo CD to this repository
for GitOps-managed deployment.

## Documentation
docs/01-overview/ - problem statement, requirements, scope.
docs/02-architecture/ - architecture, ADRs, network, security, data
flow.
docs/03-infrastructure/ - compute, Kubernetes, infrastructure as code.
docs/04-delivery/ - CI/CD, deployment strategy, rollback.
docs/05-security/ - threat model, identity, secrets, supply chain.
docs/07-reliability/ - failure modes, disaster recovery, capacity
planning.
docs/08-finops/ - cost model, optimization.
docs/09-operations/ - incident response, troubleshooting, runbooks.
docs/10-evidence/ - screenshot evidence for every major claim.

## Limitations
No live GPU-backed inference has been performed - blocked by an
external, project-level GCP quota, fully documented in ADR-006. No
observability stack (metrics, dashboards, alerting) has been
implemented. No automated tests gate pull requests before merge. No
automated rollback timing test has been performed. No disaster
recovery drill has been timed. These are stated directly rather than
omitted.

## Future improvements
Reliability: perform and time a rollback-from-bad-deployment test,
and a pod-kill recovery test, once the GPU workload is live.
Security: implement periodic secret rotation for production-grade
secrets.
Observability: implement Prometheus and Grafana for GPU/VRAM,
TTFT, TPOT, and token-throughput metrics once inference is live.
Cost: implement an automated hard billing cap via Cloud Billing
Pub/Sub notifications and a Cloud Function.
Automation: add pull-request-gating tests before merge.

## Engineering lessons
A clean kubectl apply with no error is not proof a Kubernetes security
control is active - this project's NetworkPolicy initially appeared to
work and did not, discovered only through a deliberate live test, not
by trusting the apply output.

Granting an IAM role to a node-level service account does not extend
that permission to individual pods running on that node - each pod
needs its own explicit Workload Identity binding, a gap that caused
Kyverno to fail closed on every image, including legitimate ones,
until fixed.

When multiple layers of a system all report success but the real-world
outcome contradicts them, the correct move is to find the lowest-level,
least-abstracted error source available. This project's GPU node pool
showed RUNNING at the GKE layer and DONE at the Compute Engine
operations layer while zero physical nodes existed - the real cause
was only found by reading direct Managed Instance Group error logs,
which no higher-level status check surfaced.

Infrastructure sizing decisions are more honestly reached through
measured failure and correction than through upfront estimation - the
system node pool's final configuration was the third attempt, each
prior attempt disproven by a specific, real scheduling or eviction
failure rather than by guesswork.
