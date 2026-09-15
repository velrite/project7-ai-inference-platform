# Cost Model

## Budget constraint
This entire project was built against a $300 GCP free-trial credit
ceiling, with no unlimited spending available. Every infrastructure
decision in this project was made with that ceiling as a real
constraint, not a theoretical one.

## What actually costs money in this project
The GKE control plane and the system node pool (e2-standard-2 times
up to eight nodes when autoscaled) run continuously and bill by the
hour. The NGINX Ingress Controller provisions a GCP Network Load
Balancer, which has its own small hourly charge. The GPU node pool
bills only when an actual node exists - confirmed directly, since the
pool has sat at zero physical nodes for most of this project's
history with zero associated compute cost, verified via
gcloud compute instances list showing no GPU instance present.

## What does not cost meaningful money
Terraform state storage in GCS, Artifact Registry storage for the
built images, Secret Manager entries, and IAM/Workload Identity
configuration are all negligible - fractions of a cent at this
project's scale.

## Cost discipline practiced during the build
The full cluster (control plane and system node pool) was
deliberately destroyed via Terraform at the end of working sessions
specifically to avoid unattended overnight billing, then rebuilt at
the start of the next session - this create, test, destroy cycle is
recorded as a deliberate operating discipline, not an accident of the
build process.

## Not measured
Total actual dollar spend to date has not been pulled from GCP
Billing at time of writing. Cost per inference and cost per token
cannot be calculated, since no live inference request has yet been
served - both are blocked by ADR-006.
