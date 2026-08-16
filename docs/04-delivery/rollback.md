# Rollback

## Mechanism
Because deployment is GitOps-based, rollback is a Git operation: revert
or reset the commit that changed a manifest under k8s/, push, and Argo
CD's automated sync reconciles the cluster back to the prior state.
This was not yet performed as a deliberate, timed test in this
project - the closest live evidence is the auto-prune test recorded in
docs/07-reliability/failure-modes.md, which confirmed Argo CD
correctly removes resources no longer present in Git, the same
mechanism a rollback would rely on.

## Not yet measured
Rollback duration under a deliberately broken deployment has not been
timed. This is a planned test, listed in Future Improvements in the
README, pending GPU workload availability so the test can be performed
against the real inference deployment rather than a placeholder.
