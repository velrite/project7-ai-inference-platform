# Disaster Recovery

## RTO and RPO
Not measured. This project has not performed a timed, deliberate
disaster-recovery drill. Stated plainly rather than estimated.

## What is actually recoverable, and how
The entire infrastructure layer - VPC, GKE cluster, both node pools,
IAM, Artifact Registry, Workload Identity Federation - is defined in
Terraform and has been destroyed and rebuilt successfully more than
once during this project. Application-layer state (Kubernetes
manifests under k8s/) is managed by Argo CD from this Git repository,
proven live via the auto-prune test in failure-modes.md.

## Backup strategy
Not implemented. This project has no persistent application data
requiring backup - the intended workload is a stateless inference
service, and Terraform state itself is protected by GCS bucket
versioning rather than a separate backup process.

## Single points of failure, stated plainly
The GKE control plane is zonal, not regional - a zone outage would
take the cluster down, consistent with the explicit non-goal of
multi-zone HA recorded in ADR-001. The GPU node pool is capped at one
node with no redundancy, consistent with the explicit non-goal of
multi-node inference.
