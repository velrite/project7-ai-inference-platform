# Secrets Management

## Where secrets live
Application secrets are stored in GCP Secret Manager. No secret value
appears in this Git repository, in a Kubernetes Secret object, or in
a container image at any point - verified by inspection of the
repository's .gitignore, which explicitly excludes cosign.key,
terraform.tfvars, and any *.json service-account key files.

## How workloads retrieve secrets
A pod calls the Secret Manager API directly at runtime, authenticating
through its Kubernetes Workload Identity binding rather than a
mounted credential file. This was proven live: a correctly-bound test
pod successfully retrieved a stored value, and an identical pod
without the binding was denied with an explicit IAM permission error.

## Secret lifetime and rotation
Not implemented: no automated rotation schedule exists for the one
test secret used to prove this mechanism. This is appropriate for a
demonstration secret; a real production secret would need an explicit
rotation policy, noted as a future improvement.

## The Cosign signing key
Held as a GitHub Actions Secret, never committed to the repository.
Set directly from the local key file using the GitHub CLI
(gh secret set < cosign.key) specifically to avoid the corruption risk
of pasting a multi-line key through a browser text box - a real
failure mode encountered earlier in this project, where a
browser-pasted key produced an invalid PEM error in CI until it was
re-set this way.
