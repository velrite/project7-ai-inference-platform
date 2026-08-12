# Enable all GCP APIs this project will need across every phase.
# Declaring them here (instead of enabling by hand) keeps the whole
# environment reproducible purely from Terraform + Git.

locals {
  required_apis = [
    "compute.googleapis.com",              # VPC, networking, GPU compute
    "container.googleapis.com",            # GKE
    "artifactregistry.googleapis.com",     # Container image storage
    "secretmanager.googleapis.com",        # Secrets
    "iam.googleapis.com",                  # Service accounts, IAM
    "iamcredentials.googleapis.com",       # Workload Identity token exchange
    "cloudresourcemanager.googleapis.com", # Project-level operations
    "monitoring.googleapis.com",           # Observability
    "logging.googleapis.com",              # Logging
    "billingbudgets.googleapis.com",       # Budget alerts
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
