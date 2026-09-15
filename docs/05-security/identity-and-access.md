# Identity and Access

## Human access
The project owner authenticates to GCP with their own Google account.
No shared or service-account-based human login exists in this
project.

## Machine access, CI
GitHub Actions authenticates to GCP using Workload Identity
Federation. A Workload Identity Pool and Provider trust GitHub's OIDC
issuer specifically, and an attribute condition restricts the trust to
this exact repository - a token from a different repository would not
be accepted. No JSON key exists for this identity at any point.

## Machine access, in-cluster workloads
The vLLM application and Kyverno each use a distinct Kubernetes
service account, individually bound through Workload Identity to a
correspondingly narrow GCP service account. This was not the initial
design for Kyverno - a real gap was found where Kyverno had no GCP
identity at all, causing it to fail closed on every image; the fix is
documented in ADR-006's related incident record in failure-modes.md.

## Least privilege, as implemented
The GKE node service account holds only logging-write,
monitoring-write, and artifact-read roles. The CI service account
holds only artifact-write. The vLLM application service account holds
only secret-accessor, scoped to one named secret. Kyverno's bound
identity holds only artifact-read.

## Not implemented
No periodic credential rotation process exists, since Workload
Identity Federation and Kubernetes Workload Identity both issue
short-lived, automatically-expiring tokens rather than long-lived
credentials that would need manual rotation.
