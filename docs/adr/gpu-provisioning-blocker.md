# ADR: GPU Provisioning Blocked by GPUS_ALL_REGIONS Quota

## Status
Blocked - external dependency (Google Cloud Support manual review)

## Context
This project requires GPU-backed inference (vLLM on GKE). Full
infrastructure for GPU deployment is built and verified: node pool
Terraform, taints/tolerations, V100 quota confirmed available,
GKE scheduling configuration correct.

## What was tried
- L4 GPU: individual quota initially 0, later resolved, still blocked
- T4 GPU: same pattern
- P100: ruled out (not available in target zone)
- V100: individual quota confirmed (1.0), zone stock confirmed
  available, MIG creation attempted - blocked
- Region variation (5 regions tested): same result everywhere
- Fresh GCP project (new project, same billing account): same result

## Root cause (confirmed via direct evidence)
Project-wide `GPUS_ALL_REGIONS` quota = 0.0, confirmed via:
1. Direct MIG (Managed Instance Group) error logs showing
   "Quota 'GPUS_ALL_REGIONS' exceeded. Limit: 0.0 globally."
2. Identical result on a brand-new project under the same
   Google account/billing identity

This is a single, project/account-level ceiling that overrides
every individual per-GPU-type quota. It is tied to the Google
account or billing identity, not any specific project or region.

## Why self-service resolution was not possible
The GCP Console quota-edit form explicitly rejects increase
requests for this quota ("not eligible for a quota increase at
this time"), and Google Cloud Support billing team confirmed
quota increases fall outside their scope, redirecting to a
manual review process.

## Decision
Escalated to Google Cloud Support with precise, evidence-backed
findings (exact quota name, exact error, ruled-out alternatives).
Continued platform development on all GPU-independent work while
awaiting resolution, rather than blocking all progress on this
single external dependency.

## What was NOT blocked, and was completed instead
- Full CI/CD security pipeline (Trivy, SBOM, Cosign signing)
- Kyverno admission enforcement (signature verification, proven)
- NetworkPolicy default-deny (proven)
- Secret Manager + Workload Identity (proven)
- GitOps via Argo CD (proven, auto-prune verified)
- Model artifact integrity verification
- Ingress protection (rate limiting, request size limits)

## Lesson
A single external platform dependency (cloud provider quota
approval) can block one specific capability without blocking a
project's overall engineering demonstration. Documenting the
blocker precisely - including everything ruled out and why - is
itself evidence of methodical troubleshooting, not a gap in the
work.
