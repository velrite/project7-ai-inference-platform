variable "project_id" {
  description = "GCP project ID where all resources are created"
  type        = string
}

variable "region" {
  description = "Primary GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary GCP zone for zonal resources like GPU node pools"
  type        = string
  default     = "us-central1-a"
}
