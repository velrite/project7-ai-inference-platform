# Runbook: Pod CrashLoopBackOff

## Symptoms
kubectl get pods shows a pod cycling through CrashLoopBackOff, with a
RESTARTS count climbing.

## Initial checks
Run kubectl describe pod on the affected pod and read the Events
section in full, oldest to newest. Run kubectl logs on the pod, and if
it has already restarted, add --previous to see the log from the crash
itself, not the current attempt.

## Diagnosis
If the Events section shows Insufficient cpu or Insufficient memory,
this is a scheduling problem, not a crash - see the disk-pressure and
insufficient-resource runbook instead. If logs show an application
error immediately on startup, check whether a required environment
variable, secret, or config value is missing. If the container exits
with no log output at all, check whether the image's entrypoint or
command is correct - this project encountered exactly this during
early vLLM manifest work, traced to a missing or malformed startup
argument.

## Remediation
Fix the underlying cause identified above, then apply the corrected
manifest. If this project's GitOps flow is in use, commit and push the
fix rather than applying directly with kubectl, so Argo CD's tracked
state stays consistent with the cluster.

## Verification
Confirm kubectl get pods shows Running with READY at the expected
count, and RESTARTS has stopped increasing.

## Escalation
If the same pod crashes after a verified-correct fix, check whether a
downstream dependency (Secret Manager, Artifact Registry) is itself
unreachable - see the Kyverno Workload Identity incident in
failure-modes.md as an example of a dependency-level cause presenting
as a workload-level symptom.
