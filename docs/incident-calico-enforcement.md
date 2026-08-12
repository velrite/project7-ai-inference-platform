# Incident: NetworkPolicy Enforcement Gap After Post-Creation Addon Enable

## Summary
Enabling the Calico NetworkPolicy addon on an already-running GKE cluster
(via Terraform `network_policy` + `addons_config.network_policy_config`)
did not automatically propagate the `projectcalico.org/ds-ready=true`
label to existing nodes. This left the `calico-node` DaemonSet at 0/0/0
scheduled pods, meaning NetworkPolicy objects were accepted by the API
server with no error, but silently NOT enforced.

## Impact
A `default-deny` NetworkPolicy and explicit allow rule were applied and
appeared successful, but both allowed and denied test traffic succeeded
identically - a false sense of security that would have persisted
undetected without live verification.

## Detection
Manual verification: ran curl tests from both an allowed and a denied
test pod after applying policy. Both returned HTTP 200 when only one
should have. This contradicted the expected behavior and triggered
investigation.

## Root Cause
`calico-node` DaemonSet uses a node selector
(`projectcalico.org/ds-ready=true`) that GKE's managed addon did not
retroactively apply to nodes that existed before the addon was enabled.
This is a known rough edge specific to enabling Calico enforcement
*after* cluster creation rather than at creation time.

## Fix
Manually labeled existing nodes with `projectcalico.org/ds-ready=true`,
which allowed the `calico-node` DaemonSet to schedule and become Ready.
Re-verified with live traffic tests - enforcement then worked correctly.

## Lesson
Never trust "no error on apply" as proof a Kubernetes security control
is active. NetworkPolicy, admission policies, and similar controls must
be proven with live positive AND negative traffic tests, not just a
clean `kubectl apply`. This is now standard practice for the rest of
this project's security controls (admission enforcement, RBAC, etc.).

## Follow-up
For any future cluster rebuild, enable the NetworkPolicy addon at
cluster creation time, not as a post-hoc update, to avoid this gap
entirely.
