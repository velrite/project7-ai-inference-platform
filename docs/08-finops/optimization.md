# Cost Optimization

## Decisions made specifically for cost reasons
The GPU node pool's autoscaling range is set to a minimum of zero,
meaning it costs nothing when no inference workload is actively
scheduled - this was a deliberate design choice, not a default.

V100 was selected over higher-tier GPUs like A100 specifically because
it was the smallest, cheapest GPU type with confirmed quota and zone
availability at the time - the project deliberately did not reach for
a larger GPU that would produce more impressive throughput numbers at
a materially higher cost, consistent with working backward from actual
need rather than from what looks best.

The system node pool's disk size was kept at 50GB rather than a larger
size, specifically sized to the smallest value that survived real
platform-tooling load without triggering DiskPressure - documented in
ADR-005.

## Opportunities not yet pursued
A programmatic hard billing cap - using a Cloud Billing budget
notification through Pub/Sub and a Cloud Function to automatically
disable billing at a defined threshold - was identified as available
but not implemented in this project. Currently, cost control relies on
manual node-pool teardown between sessions rather than an automated
enforcement mechanism.
