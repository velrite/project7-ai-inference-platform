# Service account the GKE worker nodes run as.
# Deliberately minimal - logging, metrics, and image pulls only.
# This is NOT for application-level permissions; that's what
# Workload Identity + per-workload service accounts are for.
resource "google_service_account" "gke_nodes" {
  account_id   = "project7-gke-nodes"
  display_name = "Project 7 GKE Node Service Account"
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_service_account" "ci_pipeline" {
  account_id   = "project7-ci-pipeline"
  display_name = "CI Pipeline Service Account"
}

resource "google_project_iam_member" "ci_pipeline_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci_pipeline.email}"
}

# Kyverno needs to PULL images to verify their Cosign signatures.
# Without this, verification fails closed (denies everything) rather
# than actually checking signatures - which is safe, but not a true
# signature-verification test.
resource "google_project_iam_member" "kyverno_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:project7-gke-nodes@velrite-tf-test.iam.gserviceaccount.com"
}

# Kyverno's admission-controller pod needs to pull images from
# Artifact Registry to verify Cosign signatures. Granting IAM to
# the node-level service account does NOT flow through to pods -
# each pod needs its own explicit Workload Identity binding.
resource "google_service_account_iam_member" "kyverno_workload_identity" {
  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kyverno/kyverno-admission-controller]"
}
