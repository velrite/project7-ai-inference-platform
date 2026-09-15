# Pod-Kill Recovery and Load Test - Real Results

## Pod-kill recovery
The running vLLM inference pod was force-deleted while healthy, to
simulate an unexpected crash. Kubernetes rescheduled a replacement
pod automatically. The pod reached Running status within seconds, but
did not report Ready until several minutes later - a first attempt to
verify recovery immediately failed for exactly this reason (connection
refused, since the new pod's model was still loading), which is itself
a real finding: recovery time for a stateful ML-serving pod must
include full model reload time, not just container restart time.

Once kubectl wait confirmed genuine readiness, an inference request
against the same Service endpoint succeeded, confirming the Service
correctly routed to the new pod with no manual intervention required.

## Load test - real, unfiltered results
Five sequential real inference requests were sent to the live,
confirmed-ready endpoint. Results, in order:

Request 1: timed out at 60s (no response within the client timeout).
Request 2: timed out at 60s.
Request 3: succeeded, 43.8s, real generated text returned.
Request 4: succeeded, 9.7s, real generated text returned.
Request 5: succeeded, 9.3s, real generated text returned.

## Interpretation
This shows a clear cold-to-warm pattern: the first two requests likely
triggered on-demand kernel compilation or memory-layout work inside
vLLM's CPU execution path that only happens once, causing them to
exceed a 60-second client timeout entirely. Once that one-time cost
was paid, response time dropped sharply and stabilized around 9-10
seconds per request for a roughly 20-token completion on CPU.

This is real, measured CPU inference behavior, not GPU performance -
see ADR-006 for why this workload is running on CPU rather than the
originally planned GPU. It should not be read as representative of
expected GPU latency, which would be materially faster.

## What was NOT measured
True concurrent load (multiple simultaneous requests), a saturation
point, and TTFT/TPOT broken out as separate metrics were not measured
in this test - this was five sequential requests only. Concurrent load
testing remains a planned next step.
