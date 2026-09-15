# Failure Modes

This document records real incidents encountered during this project's
build, each with root cause and resolution. These are not hypothetical
failure scenarios - every entry here actually happened and is traceable
to a specific fix.

## Incident: NetworkPolicy silent non-enforcement

Detection: a default-deny NetworkPolicy and one explicit allow rule
were applied with no error. A live test - curling from an allowed and
a denied test pod - showed both succeeding, when only one should have.

Root cause: the NetworkPolicy addon requires both
network_policy.enabled and addons_config.network_policy_config.disabled
set to false on the GKE cluster resource. Even with both set correctly,
the calico-node DaemonSet showed zero scheduled pods, because its node
selector, projectcalico.org/ds-ready=true, is not retroactively applied
by GKE to nodes that existed before the addon was enabled.

Resolution: manually labeled the existing nodes with
projectcalico.org/ds-ready=true, which allowed the DaemonSet to
schedule. Re-verified with the same live test - the denied pod then
correctly timed out.

Lesson: a clean kubectl apply with no error is not proof a Kubernetes
security control is active. Every subsequent control in this project
(Kyverno, ingress limits) was tested with explicit positive and
negative live cases specifically because of this incident.

## Incident: system node pool resource starvation, three-stage resolution

Detection: Calico's second Typha replica stuck in Pending state with
an Insufficient cpu scheduling event, on a single e2-small node.

Stage one: resized the node pool to e2-medium. This triggered a
different failure - Quota SSD-TOTAL-GB exceeded, limit 250GB - because
GKE's rolling node replacement briefly needs disk space for both the
old and new node simultaneously, and two 100GB-disk nodes exceeded
that quota.

Stage two: reduced disk_size_gb to 30GB specifically to fit under the
SSD quota during replacement. This resolved the quota error but caused
a new failure - repeated pod eviction with a DiskPressure node
condition, once a large container image (vllm/vllm-openai) was pulled
onto the now-smaller disk.

Stage three: settled on e2-standard-2 with a 50GB disk - enough real
headroom for platform tooling plus large image pulls, while remaining
safely under the SSD quota even during a rolling replace.

Lesson: each of the three configurations was individually reasonable
given the information available at the time. Each was disproven by a
real scheduling or eviction failure, not by guesswork - this is the
intended feedback loop of infrastructure-as-code with live
verification, not a sign of poor planning.

## Incident: Kyverno signature verification failing closed due to missing identity

Detection: a pod with a real, previously-signed image digest was
rejected by the Kyverno admission webhook with a permission-denied
error, not a signature-mismatch error.

Root cause: Kyverno's admission-controller pod had no GCP identity at
all. Granting an IAM role to the GKE node-level service account does
not automatically extend to individual pods running on that node -
each pod needs its own explicit Kubernetes Workload Identity binding,
which had not yet been configured for Kyverno specifically.

Resolution: created a dedicated Workload Identity binding for
Kyverno's Kubernetes service account, annotated the service account
with the corresponding GCP identity, and restarted the
admission-controller deployment. Re-tested with both a genuinely
non-existent image tag (correctly rejected with MANIFEST_UNKNOWN, a
true negative) and a real signed digest (correctly accepted, a true
positive).

Lesson: fail-closed behavior is the correct default, but a failure
closed for the wrong reason (a missing permission, not an actual
invalid signature) can still produce a misleading test result. Two
earlier test attempts were discarded specifically because they used
test image references that did not actually exercise the intended
signature-mismatch scenario - only a guaranteed-nonexistent reference
produced an unambiguous result.

## Incident: GPU node provisioning blocked by a project-level quota

Detection: a GPU node pool was created successfully in Terraform,
GKE reported its status as RUNNING, and the underlying Compute Engine
operations all reported DONE with no error - yet no physical node
ever appeared in kubectl get nodes.

Root cause: a Managed Instance Group error log, checked directly and
bypassing every higher-level abstraction, revealed the true error:
Quota GPUS_ALL_REGIONS exceeded, limit 0.0 globally. This is a single
project or account-level quota that overrides every individual
per-GPU-type quota (L4, T4, V100, P100 all showed non-zero individual
limits at various points, none of which mattered against this global
gate).

Resolution: not yet resolved. Escalated to Google Cloud Support with
this exact quota name and error text. Full decision record in
ADR-006, architecture-decisions.md.

Lesson: when multiple layers of a system all report success (GKE
status, Compute Engine operations) but the real-world outcome
contradicts them, the correct move is to find the lowest-level,
least-abstracted error source available - in this case, direct MIG
error logs - rather than continuing to retry at a higher layer that
cannot see the actual cause.

## Failure matrix

Pod crash: not yet tested against the real inference workload, since
the GPU pod is not yet running. Planned once ADR-006 resolves.

Node failure: not yet deliberately tested. Planned once ADR-006
resolves.

Deployment failure and rollback: not yet deliberately tested. The
underlying mechanism (Argo CD reconciliation) is proven via the
auto-prune test recorded above, but a timed rollback-from-bad-deploy
test has not been performed.

Network policy misconfiguration: tested. See the NetworkPolicy
incident above - detected via live traffic test, root-caused, and
fixed.

Admission control misconfiguration: tested. See the Kyverno incident
above - detected via live signature test, root-caused, and fixed.

Resource starvation: tested. See the node pool incident above -
detected via real scheduling failures across three stages, root-caused
each time, and fixed.

External dependency failure (cloud provider quota): tested, in the
sense that it was fully diagnosed and documented, though not resolved
- see the GPU quota incident above and ADR-006.
