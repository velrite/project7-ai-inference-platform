# Dedicated identity for the inference application itself -
# separate from gke_nodes (which is for the node/kubelet layer).
# App workloads and nodes should never share an identity.
resource "google_service_account" "vllm_app" {
  account_id   = "vllm-app-sa"
  display_name = "vLLM Application Service Account"
}

# Least privilege: this identity can ONLY read secrets, nothing else.
resource "google_project_iam_member" "vllm_app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vllm_app.email}"
}

# Workload Identity binding: allows the Kubernetes service account
# "vllm-app-ksa" in the "default" namespace to impersonate the GCP
# service account above. This is what removes the need for any
# JSON key file to ever exist.
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.vllm_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/vllm-app-ksa]"
}

# A real (but dummy/test) secret to prove the mechanism end-to-end.
resource "google_secret_manager_secret" "test_api_key" {
  secret_id = "vllm-test-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "test_api_key_value" {
  secret      = google_secret_manager_secret.test_api_key.id
  secret_data = "dummy-test-value-not-a-real-secret"
}
