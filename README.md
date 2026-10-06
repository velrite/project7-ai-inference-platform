# Project 7 — AI Inference Platform

Olamide (Velrite) — GitHub: velrite

## What this is

A GKE-based inference platform for an open-source LLM, designed around
production concerns: a signed software supply chain, admission control
that rejects unverified images, network segmentation, declarative
Kubernetes deployment, and cost tracking. Every control here is backed by
a recorded test, not just a config file.

## Infrastructure Constraint

GPU provisioning was blocked by a GCP account-level quota:

`GPUS_ALL_REGIONS = 0.0`

This was confirmed directly through instance-group error logs, and ruled
out across multiple GPU types, multiple regions, and a freshly created
project under the same billing account. The quota remained unavailable
throughout. Full investigation: `docs/adr/gpu-provisioning-blocker.md`.

## Validation Under Constraint

Because GPU provisioning was unavailable, the platform was validated
end-to-end using CPU inference (Qwen2.5-1.5B-Instruct) instead. The
following remained fully testable and were tested:

- Live inference, with real generated responses
- Load testing (sequential and concurrent)
- Pod-failure recovery
- Deployment rollback
- Terraform reproducibility (destroy/rebuild)
- Signed image supply chain
- CI/CD pipeline execution

This is an infrastructure constraint that was investigated and worked
around, not a feature that failed to ship.

## Admission Verification

| Artifact | Expected | Observed |
|---|---|---|
| Valid, signed image | Accepted | Accepted |
| Unverified image | Rejected | Rejected |

Full evidence: `docs/kyverno-signature-enforcement-evidence.md`.

## Cost Controls

The environment includes explicit teardown procedures (`scripts/teardown.sh`)
to avoid leaving infrastructure running between sessions. GPU experimentation
was additionally constrained by the account-level quota above, which
prevented any accidental GPU compute cost during validation.

Real per-workload cost attribution, pulled from actual GCP billing data via
OpenCost, is documented in `docs/finops.md`.

## Architecture

![Architecture diagram — see README source for Mermaid source]

## Status

| Component | Status | Evidence |
|---|---|---|
| Infrastructure (Terraform) | Live, reproducible | `docs/01-overview/`, `docs/02-architecture/` |
| Signed supply chain | Tested both directions | `docs/kyverno-signature-enforcement-evidence.md` |
| CI/CD pipeline | Runs via Workload Identity Federation | `.github/workflows/` |
| Live inference | Real responses generated | `docs/10-evidence/first-live-inference.md` |
| GPU deployment | Blocked — account-level GCP quota | `docs/adr/gpu-provisioning-blocker.md` |

## Quick start
cd terraform/environments/dev
terraform init
terraform plan
terraform apply


Full startup/teardown automation: `scripts/startup.sh`, `scripts/teardown.sh`.
Recovery runbook: `docs/runbooks/full-recovery.md`.

Teardown:

bash scripts/teardown.sh

(Plan-only — prints the exact `terraform apply` command to run yourself
after reviewing the destroy plan. Nothing destructive runs unattended.)

### Before running apply/destroy

- Always run Terraform from `terraform/environments/dev`, never the repo root.
- Always read the plan output before approving apply or destroy.
- After apply, the vLLM pod takes several minutes to reach Ready — it's
  loading model weights, not stuck.
- Destroying the environment deletes the Workload Identity Federation
  pool/provider CI depends on. CI will fail with `invalid_target` until
  the environment is applied again. This is expected, not a bug.
- After destroy, confirm zero cost: `gcloud compute instances list` and
  `gcloud container clusters list` should both return empty.

## Documentation

- `docs/01-overview/` — problem statement, requirements, goals/non-goals
- `docs/02-architecture/` — system design, component decisions
- `docs/03-infrastructure/` — compute, Kubernetes, IaC
- `docs/04-delivery/` — CI/CD, deployment, rollback
- `docs/05-security/` — threat model, identity, secrets, supply chain
- `docs/07-reliability/` — failure modes, load tests, disaster recovery
- `docs/finops.md` — cost model, real spend, real per-workload attribution
- `docs/09-operations/` — incident response, troubleshooting, runbooks
- `docs/10-evidence/` — live inference and test evidence
- `docs/runbooks/full-recovery.md` — full environment recovery procedure

## About

AI inference platform on GKE — Terraform, vLLM, DevSecOps.
