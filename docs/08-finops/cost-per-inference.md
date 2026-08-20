# Cost Per Inference - Real Calculation

## Inputs
This platform ran primarily on a single e2-standard-2 system node and,
for the inference workload specifically, a single e2-standard-4 CPU
inference node (created on demand, autoscaled to zero when idle).
Actual GCP billing data for the full project lifetime should be
pulled from console.cloud.google.com/billing/013DE6-EC3402-FF40E4/reports
and inserted here as a specific dollar figure - not estimated in this
document, consistent with this project's standard of not fabricating
cost figures.

## Method, once real spend is confirmed
Total infrastructure spend for the period the CPU inference pool was
running, divided by the total number of real inference requests served
during that period (a small, known number from this project's own load
and verification tests - approximately 10-15 real completions were
generated across all testing in this project). This yields an
approximate cost-per-inference figure specific to this demo-scale
deployment, not representative of production-scale unit economics
where fixed costs amortize across far more requests.

## Honest caveat
At this project's small request volume, cost-per-inference is
dominated by fixed infrastructure cost (the node running whether or
not it's serving), not by marginal compute per request. A meaningful
unit-economics figure would require sustained real traffic over a
longer period - not performed in this project, noted here rather than
estimated.
