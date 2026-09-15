# GPU Deployment Blocker - Root Cause Confirmed

## The real blocker
`GPUS_ALL_REGIONS` quota = 0.0 globally, confirmed via direct MIG error logs:

"Quota 'GPUS_ALL_REGIONS' exceeded. Limit: 0.0 globally."

## What this means
This is a project-wide ceiling that overrides ALL individual GPU-type
quotas (L4, T4, V100, P100 all show non-zero limits individually, but
none of them matter while this global gate is closed).

## What was tried and ruled out
- L4: blocked (individual quota was 0, now non-zero, still blocked by global gate)
- T4: blocked (same)
- P100: blocked (wrong zone, then same global gate)
- V100: quota confirmed open (1.0), zone confirmed has stock,
  MIG confirmed attempting creation - STILL blocked by global gate

## Confirmed NOT the cause
- Billing (verified in good standing)
- Individual GPU type quota (all open)
- Zone availability (V100 confirmed available in all us-central1 zones)
- Terraform/GKE configuration (node pool, IAM, WIF all correct)

## What actually fixes this
Manual increase of `GPUS_ALL_REGIONS` quota by Google support -
self-service form explicitly rejects this specific quota
("not eligible for a quota increase at this time").

## Status
Awaiting Google Cloud Support manual review (case referenced Aug 15, 2026).
