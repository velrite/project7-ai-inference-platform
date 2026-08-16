# Compute

## System node pool
Machine type e2-standard-2, 50GB disk, autoscaling between 1 and 8
nodes. Hosts all platform tooling: Calico's control-plane components,
Kyverno, Argo CD, and the NGINX Ingress Controller. This sizing was
reached after three real scheduling and eviction failures during the
build - documented in ADR-005 and failure-modes.md - not chosen
upfront from a sizing guide.

## GPU node pool
Machine type n1-standard-4, paired with one NVIDIA V100 GPU, 100GB
disk, autoscaling between 0 and 1 node, with a taint
(nvidia.com/gpu=present:NoSchedule) so only pods with a matching
toleration can be scheduled onto it. The pool definition exists and
was created successfully in Terraform. A physical node has not yet
been provisioned - see ADR-006.

## Why V100 rather than the originally planned L4
L4 was the original choice for cost and availability reasons. Its
quota, along with T4's, remained blocked by the project-level
GPUS_ALL_REGIONS constraint described in ADR-006. V100 was selected
once L4 and T4 quota checks and P100 zone-availability checks were
exhausted, as the GPU type with confirmed individual quota and
confirmed zone stock - it was ultimately blocked by the same
project-level constraint, which was not yet understood at the time
V100 was selected.
