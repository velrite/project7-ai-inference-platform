resource "google_artifact_registry_repository" "inference" {
  location      = var.region
  repository_id = "project7-inference"
  format        = "DOCKER"
  description   = "Container images for the vLLM inference platform"

  depends_on = [google_project_service.required]
}
