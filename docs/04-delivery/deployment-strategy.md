# Deployment Strategy

## Mechanism
Deployment is GitOps-based, not push-based. CI's responsibility ends
at producing a signed, scanned image in Artifact Registry. Argo CD,
running on the cluster, separately watches the k8s/ path in this
repository and reconciles the live cluster state to match what is
committed - this separation means CI never has direct kubectl or
cluster-admin access, which was a deliberate choice.

## Rollout behavior
Kubernetes' default Deployment rolling-update strategy applies. No
custom rollout strategy (canary, blue-green) is configured, consistent
with a single-replica, non-HA workload.

## Promotion
There is one environment in this project. Promotion between
environments is not applicable and not implemented.

## Verification before merge
No automated tests currently gate a pull request before merge - see
Limitations in the README for this gap stated plainly.
