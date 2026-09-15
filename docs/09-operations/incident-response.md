# Incident Response

## Approach used throughout this project
Every real incident encountered during the build followed the same
pattern: detect via a live test rather than trust a clean apply,
gather the lowest-level available evidence rather than guess at a fix,
apply a targeted correction, then re-verify with the same live test
that originally caught the problem. This pattern is documented in
detail, incident by incident, in docs/07-reliability/failure-modes.md.

## Escalation
The one incident that could not be resolved within this project's own
control - the GPUS_ALL_REGIONS quota block described in ADR-006 - was
escalated to Google Cloud Support with the most specific, actionable
evidence available: the exact quota name and the exact MIG error text,
rather than a general description of symptoms. This is treated as the
correct escalation practice: give a reviewer the smallest, most
precise piece of evidence that lets them act, not a broad narrative.
