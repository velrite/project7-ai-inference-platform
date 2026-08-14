# GKE Standard, zonal (not regional) - matches stated project scope,
# which explicitly excludes multi-zone/multi-node HA as a non-goal.
resource "google_container_cluster" "primary" {
  name     = "project7-cluster"
  location = var.zone

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # We manage node pools explicitly - never run workloads on
  # GKE's auto-created default pool.
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false # demo project - we WILL tear this down

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  depends_on = [google_project_service.required]
}

# Small always-on pool for non-GPU platform workloads
# (ingress controller, Argo CD, monitoring agents).
# Keeps expensive GPU nodes free of unrelated pods.
resource "google_container_node_pool" "system" {
  name       = "system-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.zone
  node_count = 1

  node_config {
    machine_type    = "e2-standard-2"
    disk_size_gb    = 30
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "system"
    }
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }
}

# NOTE: network_policy must be enabled for GKE to actually ENFORCE
# NetworkPolicy objects. Without this, Kubernetes accepts the policy
# YAML with no error, but silently does nothing - which is exactly
# what we just proved by testing it live.
