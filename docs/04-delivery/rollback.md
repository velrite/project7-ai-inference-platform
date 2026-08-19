# Rollback - Real GitOps Test

## Test performed
A deliberately broken image tag (a nonexistent tag on the real
registry path) was committed and pushed to the k8s/ manifests
directory. Argo CD, configured with automated sync and self-heal,
was reinstalled for this test and confirmed connected to this
repository before the test began.

## What actually happened
The broken commit was picked up by Argo CD's sync within seconds of
being pushed. A new pod was created for the broken image tag, but it
never displaced the existing healthy pod - the cpu-inference-pool
node pool is capped at a single node
(min_node_count 0, max_node_count 1, see ADR-005 for the reasoning),
so there was no spare capacity for a second pod to be scheduled
alongside the running one. The new pod sat Pending with
FailedScheduling events (Insufficient cpu, Insufficient memory) while
the original, working pod continued serving traffic uninterrupted the
entire time.

Once the fix was committed and pushed, Argo CD synced again within
seconds, and the pending broken pod was cleared. The original healthy
pod - the same one from before the test began, confirmed by its pod
name and uptime - was never restarted or replaced throughout the
entire experiment.

## Real finding
This single-node capacity constraint produced an unintentional but
genuine safety property: a broken deployment could not take down the
running service, because Kubernetes' rolling-update strategy will not
terminate a healthy pod until its replacement is confirmed ready, and
here the replacement could never even get scheduled. This is not a
deliberately engineered rollback-prevention mechanism - it is a
side effect of the node pool's deliberately minimal sizing (see
ADR-005) - but it is a real, observed, and worth-documenting behavior.

## What this means for rollback timing
Traditional rollback-duration timing (measuring downtime between a
bad deployment and a restored good one) does not apply here, because
no downtime occurred - the bad deployment never became live. The
GitOps mechanism itself was proven working end to end: a Git push
correctly triggered automated detection and sync in both directions
(breaking and fixing), each completing within seconds.

## What would need to change to observe true rollback timing
Increasing max_node_count on the CPU inference pool to 2 would allow
a bad pod to actually schedule and run, allowing a genuine
detection-then-recovery timing measurement, at the cost of temporarily
running two nodes during any future rollout. Not implemented in this
test - noted as a valid follow-up, not performed, to keep this test
scoped to the single-node configuration this project actually runs.
