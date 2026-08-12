# Custom VPC - explicit, not the GCP default network.
# Every subnet and route here exists because we defined it,
# which is what lets us explain and test network boundaries later.
resource "google_compute_network" "main" {
  name                    = "project7-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}

# Single subnet, VPC-native (alias IP ranges), sized generously
# since IP space is free and running out mid-build is a real risk.
resource "google_compute_subnetwork" "main" {
  name          = "project7-subnet"
  ip_cidr_range = "10.10.0.0/20" # ~4,096 node IPs
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16" # ~65,536 pod IPs
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20" # ~4,096 service IPs
  }

  private_ip_google_access = true
}
