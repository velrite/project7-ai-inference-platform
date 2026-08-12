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
