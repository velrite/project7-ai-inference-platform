# Kubernetes

## Cluster topology
One zonal GKE Standard cluster, project7-cluster, in us-central1-a.
Two node pools: system-pool and gpu-pool, described in compute.md.

## Namespaces
default: application workloads, including the vLLM deployment and
service, and the test pods used to prove security controls.
kyverno: the Kyverno admission controller and its supporting
components.
argocd: the Argo CD server and controllers.
ingress-nginx: the NGINX Ingress Controller.
kube-system: GKE-managed system components, including Calico.

## Workloads present
vllm-inference Deployment and Service: the intended GPU inference
workload. Deployed, not yet running - blocked on GPU node
provisioning.
echo-test Deployment and Service: a lightweight test backend used to
prove ingress rate limiting and size limits.

## RBAC
Kyverno and the vLLM application each use a dedicated Kubernetes
service account bound through Workload Identity to a correspondingly
narrow-scoped GCP service account, rather than sharing the default
service account or the node-level identity.

## NetworkPolicy
A default-deny NetworkPolicy applies cluster-wide to ingress traffic,
with one explicit allow rule for pods labeled access=granted. Proven
live - see failure-modes.md for the real incident encountered while
enabling enforcement.

## Not implemented
HorizontalPodAutoscaler, PodDisruptionBudget, and StatefulSets are not
used in this project. The GPU workload is intentionally single-replica
by design (see goals-and-non-goals.md), so HPA and PDB were not
required to demonstrate the project's actual scope. Topology spread
constraints and pod affinity/anti-affinity rules are not configured -
not applicable to a single-zone, non-HA cluster.
