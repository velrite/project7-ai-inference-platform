# Runbook: Node DiskPressure

## Symptoms
Pods repeatedly show STATUS Evicted, and kubectl describe node shows a
DiskPressure condition set to True.

## Initial checks
Run kubectl describe node on the affected node and read the Conditions
section for the exact DiskPressure status and timestamp. Run
kubectl get pods -A to gauge how many pods have been evicted.

## Diagnosis
This project's actual root cause was a node disk sized too small to
hold both platform-tooling overhead and a large container image pull
simultaneously - full incident record in ADR-005 and failure-modes.md.
Check the node pool's configured disk_size_gb in Terraform against
what is actually being asked to run on it.

## Remediation
Increase disk_size_gb in the relevant Terraform node pool resource,
plan, review the plan in full, then apply. Be aware that increasing
disk size on an existing pool triggers a rolling node replacement,
which briefly needs disk space for both old and new nodes - check
regional SSD quota headroom before applying, since this project hit
that exact secondary quota limit during this same remediation.

## Verification
Confirm kubectl describe node no longer shows DiskPressure as True,
and previously-evicted pods successfully reschedule and reach Running.

## Escalation
If increasing disk size alone does not resolve it, check what is
actually consuming space with kubectl describe node's Allocated
resources section - platform tooling overhead (Calico, Kyverno, Argo
CD) may itself need a larger machine type, not just a larger disk, as
happened in this project's system-pool sizing history.
