# 1. Habilitar APIs requeridas (Actualizado para Lab 2)
resource "google_project_service" "services" {
  for_each = toset([
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "firestore.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "eventarc.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# 2. Bucket de Cloud Storage (Bronze - Raw staging)
resource "google_storage_bucket" "bronze_raw_bucket" {
  name                        = "${var.project_id}-bronze-raw"
  location                    = var.region
  force_destroy               = true # Permite borrar el bucket con datos en el laboratorio
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.services]
}

# 3. Datasets de BigQuery para la arquitectura Medallion

# Capa Bronze (Datos crudos en BigQuery)
resource "google_bigquery_dataset" "bronze_dataset" {
  dataset_id  = "bronze"
  description = "Capa Bronze: Datos en bruto sin procesar"
  location    = var.bq_location

  depends_on = [google_project_service.services]
}

# Capa Silver (Datos limpios, tipados y de-duplicados)
resource "google_bigquery_dataset" "silver_dataset" {
  dataset_id  = "silver"
  description = "Capa Silver: Datos limpios, estructurados y validados"
  location    = var.bq_location

  depends_on = [google_project_service.services]
}

# Capa Gold (Datos agregados y listos para negocio/BI)
resource "google_bigquery_dataset" "gold_dataset" {
  dataset_id  = "gold"
  description = "Capa Gold: Tablas agregadas y optimizadas para analítica"
  location    = var.bq_location

  depends_on = [google_project_service.services]
}

# 4. Base de datos Firestore (Modo Nativo)
# NOTA: En GCP solo se permite una base de datos "(default)" por proyecto.
resource "google_firestore_database" "firestore_db" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.services]
}