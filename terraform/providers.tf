terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
  # Configuración del Backend Remoto
  backend "gcs" {
    bucket = "curso-gcp-medallion-tfstate" # Reemplaza por tu ID de proyecto real + -tfstate
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

