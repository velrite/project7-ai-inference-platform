# Data Flow

## Build and deployment flow
A developer commits code and pushes to the master branch on GitHub.
This triggers the CI workflow, which authenticates to GCP through
Workload Identity Federation, builds the container image, pushes it
to Artifact Registry, scans it with Trivy, generates an SBOM with
Syft, and signs the pushed image with Cosign. Separately, Argo CD
polls the same GitHub repository, detects any change under the k8s/
path, and syncs the cluster's actual state to match - this was proven
live when removing an abandoned deployment manifest from Git resulted
in Argo CD automatically pruning that deployment from the running
cluster with no manual kubectl command involved.

## Intended inference request flow
A client request would reach the NGINX Ingress, pass its rate-limit
and body-size checks, and route to the vLLM Service, which forwards
to the vLLM pod running on the GPU node pool. This full path is not
yet verified end to end, since the GPU pod itself cannot currently
schedule - see ADR-006 in architecture-decisions.md. Every component
up to and including the Ingress and Service definitions has been
deployed and is real; only the final GPU-backed pod is pending.

## Secret retrieval flow
A pod with the correct Workload Identity binding calls the Secret
Manager API directly, using its Kubernetes service account's
federated identity to authenticate - no key file, no environment
variable holding a static secret. This was proven live.
