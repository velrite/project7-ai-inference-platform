# Cost Per Inference - Real Calculation

## Real spend, confirmed via GCP Billing Reports (Aug 1-19, 2026)
Kubernetes Engine: $10.63 usage cost.
Compute Engine: $12.98 usage cost.
Networking: $2.02 usage cost.
Cloud Monitoring: $1.80 usage cost.
Artifact Registry: $0.07 usage cost.
Total usage cost: $27.50.

All usage cost was offset by GCP's free-trial savings program, for a
net billed amount of $0.00 for this period. Separately, a one-time
$10.00 payment was made to reactivate the billing account after it
was closed pending payment verification - this was an account-level
charge, not a resource-usage charge, and is not included in the
$27.50 usage total above.

## Cost per inference, using real usage cost
Approximately 10-15 real inference requests were served across all
testing in this project (initial verification, pod-kill recovery
test, sequential load test, concurrent load test). Using the $27.50
real usage cost figure and the upper estimate of 15 requests:

$27.50 / 15 requests = approximately $1.83 per inference request.

## Why this number is not representative of production economics
This figure is dominated entirely by fixed infrastructure cost - the
GKE control plane, node pools, and networking that ran for the full
project duration regardless of request volume - divided across a very
small number of test requests. It is not a meaningful unit-economics
figure for a production system. At realistic production request
volumes (thousands or more requests against the same fixed
infrastructure), this same $27.50 would amortize to a small fraction
of a cent per request. This calculation is included to demonstrate
the methodology, using real project data, not to represent expected
production cost per inference.

## Note on trial credit
All usage cost in this project was covered by free-trial savings,
resulting in $0.00 net billed for resource usage. The only real
out-of-pocket cost across this entire project was the one-time $10.00
billing-account reactivation payment.
