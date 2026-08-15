# Workload Identity Federation lets GitHub Actions authenticate to GCP
# using short-lived OIDC tokens instead of a long-lived JSON key.
# This is the correct pattern - and it sidesteps the org policy that
# blocks static service-account key creation entirely, since no key
# file is ever created.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions CI"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Restrict to ONLY this specific repo - least privilege
  attribute_condition = "assertion.repository == \"velrite/project7-ai-inference-platform\""
}

# Allow GitHub Actions from this specific repo to impersonate
# the CI service account - no key file needed
resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.ci_pipeline.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/velrite/project7-ai-inference-platform"
}
