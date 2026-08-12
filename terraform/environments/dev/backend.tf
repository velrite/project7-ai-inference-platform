terraform {
  backend "gcs" {
    bucket = "velrite-project7-tfstate"
    prefix = "dev"
  }
}
