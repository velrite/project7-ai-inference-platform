# Dedicated CPU inference node pool - separate from system-pool so
# platform tooling (Kyverno, Argo CD, NGINX) never competes with the
# inference workload for resources. Sized from real prior failures:
# e2-standard-4 (4 vCPU/16GB) and 60GB disk avoid both the
# Insufficient-memory and DiskPressure incidents recorded in ADR-005.
resource "google_container_node_pool" "cpu_inference" {
  name     = "cpu-inference-pool"
  cluster  = google_container_cluster.primary.name
  location = var.zone

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  node_config {
    machine_type    = "e2-standard-4"
    disk_size_gb    = 60
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "cpu-inference"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
