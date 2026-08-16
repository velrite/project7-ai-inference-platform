# Runbook: Failed or Stuck Deployment

## Symptoms
kubectl get pods shows a new pod stuck in Pending, or an Argo CD app
shows Sync Status as OutOfSync or Health Status as Degraded for longer
than expected.

## Initial checks
Run argocd app get on the application to see its current sync and
health status alongside each managed resource. Run kubectl describe
pod on any Pending pod and read Events in full.

## Diagnosis
A FailedScheduling event citing node affinity or selector mismatch
means the pod's nodeSelector or toleration does not match any
available node - check that the target node pool actually has a
running node, not just a defined pool, since this project encountered
exactly this gap with the GPU node pool (defined and RUNNING at the
pool level, zero physical nodes present - see ADR-006). A
FailedScaleUp event citing a quota error is an external, cloud
provider-level block, not a Kubernetes configuration problem - check
the exact quota name in the error text directly, as was done in this
project's GPU quota investigation.

## Remediation
For a genuine configuration error, correct the manifest and push
through Git so Argo CD reconciles it. For an external quota block,
this is not resolvable from inside the cluster - escalate as described
in incident-response.md.

## Verification
Confirm the pod reaches Running and Ready, and argocd app get reports
Synced and Healthy.

## Escalation
If Argo CD itself is unresponsive or shows no sync activity, check
that the argocd-server pod is running and that the port-forward or
ingress path to it is intact - this project's Argo CD session dropped
more than once during long working sessions and required a
re-established port-forward and re-login, not a configuration fix.
