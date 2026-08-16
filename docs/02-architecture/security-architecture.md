# Security Architecture

## Human authentication
Access to the GCP project is authenticated through the operator's
Google account. No shared credentials or service-account
impersonation is used for human access in this project.

## Workload authentication
Two distinct patterns are used, and they are kept separate
deliberately. GitHub Actions authenticates to GCP through Workload
Identity Federation - a short-lived OIDC token exchange, no key file
ever exists. Kubernetes pods that need GCP resources (the vLLM
application, and separately Kyverno) authenticate through Kubernetes
Workload Identity - a named Kubernetes service account is bound to a
specific GCP service account, and only that exact pairing works.

## Authorization
GCP IAM roles are scoped narrowly per service account. The GKE node
service account has only logging, monitoring, and artifact-read
permissions. The CI service account has only artifact-write
permissions. The vLLM application service account has only
Secret-Manager-read permission on one specific secret. Kyverno's
service account has only artifact-read permission, added after a real
incident where its absence caused signature verification to fail
closed - see failure-modes.md.

## Secrets
Application secrets live in GCP Secret Manager, never in Kubernetes
Secrets, environment variables, or Git. Access is proven live: a pod
with the correct Workload Identity binding successfully reads a
secret value, and a pod without that binding is denied with an
explicit IAM permission error, not a silent failure.

## Encryption
Data at rest in GCP-managed services (Artifact Registry, Secret
Manager, persistent disks) uses Google-managed encryption by default.
No customer-managed encryption keys were configured - not required
for this project's threat model.

## Container security
Every image is scanned with Trivy before being allowed to proceed
through the pipeline, with a documented severity policy: fail on
CRITICAL, allow HIGH and below through with a required exception
record. One real CRITICAL finding, CVE-2025-37797 in linux-libc-dev,
was found, evaluated for actual exploitability - the vulnerable ksmbd
kernel component is never used by this workload - and formally
excepted via a documented .trivyignore entry rather than being
silently ignored or used to lower the overall bar.

## Supply-chain security
Every image is signed with Cosign using an ECDSA keypair, keyed to
the exact image digest, never a mutable tag. A Kyverno ClusterPolicy
enforces signature verification at admission time - a pod referencing
an image with no valid signature is rejected before it can run, tested
live with both a genuinely non-existent tag and cross-checked against
a real signed digest.
