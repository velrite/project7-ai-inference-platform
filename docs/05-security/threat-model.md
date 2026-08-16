# Threat Model

## Assets
The container image and its build pipeline. The model artifact
intended to be loaded at runtime. GCP IAM credentials and service
account bindings. Secrets held in Secret Manager. The Kubernetes API
server and its admission path. The public-facing ingress endpoint.

## Trust boundaries
GitHub Actions to GCP - crossed via Workload Identity Federation only.
Container registry to running cluster - crossed via Kyverno signature
verification only. External network to cluster - crossed via the
NGINX Ingress only. Pod to Secret Manager - crossed via per-pod
Workload Identity only.

## Threats considered and their mitigation
A compromised or tampered container image reaching production: mitigated
by Trivy scanning plus Cosign signing plus Kyverno admission
enforcement, each independently tested live.
A compromised or corrupted model artifact loaded silently: mitigated by
a separate checksum-verification script, since container-image
integrity does not imply model-weight integrity - tested live with a
genuine tamper-detection case.
Unauthorized pod-to-pod lateral movement: mitigated by a default-deny
NetworkPolicy - tested live, including a real incident where the
control initially failed silently before being corrected.
A leaked or overly-broad credential: mitigated by scoping every
service account to the minimum role it needs, and by using Workload
Identity Federation specifically so no long-lived CI key exists to
leak in the first place.
Resource exhaustion of an expensive inference endpoint by a single
abusive client: mitigated by ingress-level rate limiting and request
size limits, both tested live under real load.

## Threats explicitly out of scope
Distributed denial-of-service at the network layer, multi-tenant
isolation between separate customers, and model-output content
safety are not addressed by this project - see Non-Goals in
docs/01-overview/goals-and-non-goals.md.
