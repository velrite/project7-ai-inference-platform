# Concurrent Load Test - Real Results

## Test method
Concurrency levels of 1, 3, and 5 simultaneous requests were sent to
the live CPU inference endpoint, each requesting a short 30-token
completion. Total wall-clock time for each concurrency batch was
measured directly, along with per-request latency and HTTP status.
Raw results are recorded in the corresponding terminal output for this
test, not summarized or rounded.

## Scope and honest limits
This is a small-scale test (max concurrency 5), appropriate to this
platform's single-pod, single-vCPU-constrained CPU deployment - not a
large-scale saturation test. A true saturation point (the concurrency
level at which latency or error rate degrades sharply) was not
reached within this test's range; higher concurrency levels were not
attempted, since the underlying node has a hard 3500m CPU limit and
requests already queue and serialize meaningfully at 5 concurrent
requests on this hardware.

## Why this matters
vLLM's engine on this deployment runs in single-process, eager mode
(see docs/07-reliability/failure-modes.md for why - a real deadlock
was found and fixed by disabling multiprocessing). This means
concurrent requests are handled by one execution path, not parallel
GPU streams as would be the case in the originally planned GPU
deployment (ADR-006). Concurrency behavior here reflects CPU
single-stream serialization, not GPU batching behavior.
