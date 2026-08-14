# GPU node pool - scales to ZERO when idle, this is the primary
# cost control for the whole project. Creating this resource does
# NOT immediately cost L4-GPU money; a node only spins up (and
# starts billing) once something actually requests the GPU.
resource "google_container_node_pool" "gpu" {
  name     = "gpu-pool"
  cluster  = google_container_cluster.primary.name
  location = var.zone

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  node_config {
    machine_type    = "n1-standard-4"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    guest_accelerator {
      type  = "nvidia-tesla-v100"
      count = 1
    }

    spot = false

    labels = {
      pool = "gpu"
    }

    # Repel ordinary pods by default - only pods that explicitly
    # tolerate this taint (i.e. actually need a GPU) get scheduled here.
    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
