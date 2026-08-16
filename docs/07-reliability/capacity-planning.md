# Capacity Planning

## System node pool
Reached its current sizing, e2-standard-2 with a 50GB disk, through
three real, measured scheduling and eviction failures rather than
upfront estimation - the full sequence is recorded in ADR-005 and
failure-modes.md. This is treated as the more honest record: the
final sizing reflects what was actually needed under real platform
tooling load (Calico, Kyverno, Argo CD, NGINX Ingress running
simultaneously), not a guess that happened to work.

## GPU node pool
Capped at a maximum of one node by deliberate design, matching the
project's explicit non-goal of multi-node inference. Machine type
n1-standard-4 paired with one V100 GPU was selected based on
confirmed quota and confirmed zone hardware availability at the time,
documented in ADR-006 - though the pool has not yet successfully
provisioned a physical node due to the project-level quota blocker
described in that same ADR.

## Regional quota limits encountered
SSD-TOTAL-GB: 250GB limit in us-central1, actually reached during a
node pool resize and directly caused a real failure - documented in
ADR-005.
GPUS_ALL_REGIONS: 0.0 limit, project-level, the central blocker
documented in ADR-006.

## Not measured
Application-level throughput, latency percentiles, and a saturation
point under concurrent load have not been measured, since they require
a running GPU-backed inference pod. This is explicitly blocked by
ADR-006, not omitted by choice.
