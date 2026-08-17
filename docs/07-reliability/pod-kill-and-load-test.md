# Pod-Kill Recovery and Load Test - Real Results

## Pod-kill recovery
The running vLLM inference pod was force-deleted while healthy, to
simulate an unexpected crash. Kubernetes rescheduled a replacement
pod automatically. Recovery time - from deletion to the new pod
reporting Ready, including full model reload - was measured directly
and is recorded in the corresponding terminal output, not estimated.

After recovery, a fresh inference request was sent to the same Service
endpoint and confirmed a successful response, proving the Service
correctly routed to the new pod with no manual intervention.

## Load test
Five sequential real inference requests were sent to the live
endpoint, each with per-request latency captured via curl's own
timing output. This is a small, sequential test, not a concurrency
or saturation test - full load testing to a saturation point remains
a planned next step. These five data points are the first real,
measured latency numbers this platform has produced.

## Note
This test ran against the CPU-based inference deployment, not the
originally planned GPU deployment - see ADR-006. Latency numbers here
reflect CPU inference speed and are not representative of expected
GPU performance.
