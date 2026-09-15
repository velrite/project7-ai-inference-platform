# Infrastructure as Code

## Approach
Every core resource in this project - VPC, subnet, GKE cluster, both
node pools, IAM service accounts and bindings, Artifact Registry,
Secret Manager entries, and Workload Identity Federation configuration
- is defined in Terraform. No core resource was created by hand
through the GCP console at any point.

## State management
Terraform state is stored remotely in a versioned GCS bucket
(velrite-project7-tfstate), created once outside Terraform since a
backend cannot bootstrap itself. Versioning is enabled so a corrupted
or bad state file can be rolled back.

## Change discipline
Every apply in this project was preceded by a plan, and every plan
with more than a handful of resources was read in full before
approving the apply - this discipline directly caught several
mistakes during the build, including a wrong machine-type and
accelerator-type pairing that would otherwise have failed at apply
time with a less clear error.

## Targeted applies
The -target flag was used repeatedly during active debugging, to
apply one specific fix without also re-attempting an unrelated,
currently-blocked resource (the GPU node pool, while quota was
unresolved). This is a deliberate, documented deviation from
Terraform's own guidance against routine -target use, adopted
specifically to avoid re-triggering a known-failing apply on every
unrelated change.

## Reproducibility
The full environment - network, cluster, both node pools, IAM, and
Artifact Registry - has been destroyed and rebuilt more than once
during this project, each time successfully, using only the Terraform
files in this repository. This is treated as the definition of "the
environment is properly infrastructure-as-code," not merely a
convenience.
