# 1. Crear Tabla Raw en la Capa Bronze de BigQuery
resource "google_bigquery_table" "firestore_customers_raw" {
  dataset_id          = google_bigquery_dataset.bronze_dataset.dataset_id
  table_id            = "firestore_customers_raw"
  deletion_protection = false # Permite destruir la tabla en pruebas sin bloqueo

  schema = <<EOF
[
  {
    "name": "document_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "ID único del documento de Firestore"
  },
  {
    "name": "event_type",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Tipo de evento de mutación (create, update, delete)"
  },
  {
    "name": "event_timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Fecha y hora en la que ocurrió el evento"
  },
  {
    "name": "data",
    "type": "JSON",
    "mode": "NULLABLE",
    "description": "Payload crudo serializado del documento"
  }
]
EOF
}

# 2. Comprimir y subir código fuente de la función
data "archive_file" "firestore_cf_source" {
  type        = "zip"
  source_dir  = "${path.module}/../src/firestore_trigger"
  output_path = "${path.module}/files/firestore_trigger.zip"
}

resource "google_storage_bucket_object" "firestore_cf_zip" {
  name   = "firestore_trigger_${data.archive_file.firestore_cf_source.output_md5}.zip"
  bucket = google_storage_bucket.gcf_source_bucket.name
  source = data.archive_file.firestore_cf_source.output_path
}

# 3. Cuenta de servicio dedicada para la ejecución de la Cloud Function
resource "google_service_account" "cf_firestore_sa" {
  account_id   = "sa-firestore-to-bq"
  display_name = "Service Account para replicar de Firestore a BigQuery"
}

# 4. Asignar roles necesarios a la Cuenta de Servicio de la función
# Permiso de escritura y streaming sobre la tabla de BigQuery
resource "google_project_iam_member" "bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.cf_firestore_sa.email}"
}

# Permiso para ejecutar jobs de consulta de BigQuery
resource "google_project_iam_member" "bq_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.cf_firestore_sa.email}"
}

# Permiso para actuar como receptor de Eventarc
resource "google_project_iam_member" "eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.cf_firestore_sa.email}"
}

# 5. Desplegar la Cloud Function Gen 2 con trigger de Firestore
resource "google_cloudfunctions2_function" "firestore_to_bq_func" {
  name        = "firestore-to-bq"
  location    = var.region
  description = "Pipeline en tiempo real: Replicación CDC de Firestore a BigQuery"

  build_config {
    runtime     = "python311"
    entry_point = "sync_firestore_to_bq"
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_source_bucket.name
        object = google_storage_bucket_object.firestore_cf_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "512Mi"
    timeout_seconds    = 60
    
    environment_variables = {
      DATASET_ID = google_bigquery_dataset.bronze_dataset.dataset_id
      TABLE_ID   = google_bigquery_table.firestore_customers_raw.table_id
    }
    
    service_account_email = google_service_account.cf_firestore_sa.email
  }

  # Configuración del Trigger de Eventarc
  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.firestore.document.v1.written" # Detecta create, update y delete
    service_account_email = google_service_account.cf_firestore_sa.email

    event_filters {
      attribute = "database"
      value     = "(default)" # Base de datos Firestore configurada en el Lab 1
    }
    
    # Patrón de coincidencia para escuchar cambios sobre cualquier ID de cliente en la colección "customers"
    event_filters {
      attribute = "document"
      value     = "customers/{customerId}"
      operator  = "match-path-pattern"
    }
  }

  depends_on = [
    google_project_iam_member.bq_editor,
    google_project_iam_member.bq_user,
    google_project_iam_member.eventarc_receiver,
    google_bigquery_table.firestore_customers_raw
  ]
}

# 7. Permitir llamadas públicas HTTP de prueba (Solo para desarrollo en este lab)
resource "google_cloud_run_service_iam_member" "public_invoker_firestore" {
  location = google_cloudfunctions2_function.firestore_to_bq_func.location
  service  = google_cloudfunctions2_function.firestore_to_bq_func.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}