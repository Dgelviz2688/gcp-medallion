# 1. Crear Tabla de Órdenes en la Capa Bronze de BigQuery
resource "google_bigquery_table" "orders_raw" {
  dataset_id          = google_bigquery_dataset.bronze_dataset.dataset_id
  table_id            = "orders_raw"
  deletion_protection = false

  schema = <<EOF
[
  {
    "name": "id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "ID único de la orden"
  },
  {
    "name": "customer_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "ID del cliente de Firestore que realizó la compra"
  },
  {
    "name": "product_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "ID del producto comprado"
  },
  {
    "name": "amount",
    "type": "FLOAT",
    "mode": "REQUIRED",
    "description": "Monto total de la compra"
  },
  {
    "name": "order_date",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Fecha de la transacción (mantenida como string en Bronze)"
  }
]
EOF
}

# 2. Configurar permisos especiales de GCS para publicar eventos en PubSub / Eventarc
# NOTA CLAVE: Sin este permiso, Eventarc no podrá capturar las subidas de archivos a Storage.
data "google_storage_project_service_account" "gcs_account" {}

resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# 3. Comprimir y subir código fuente de la función
data "archive_file" "batch_cf_source" {
  type        = "zip"
  source_dir  = "${path.module}/../src/ingest_batch"
  output_path = "${path.module}/files/ingest_batch.zip"
}

resource "google_storage_bucket_object" "batch_cf_zip" {
  name   = "ingest_batch_${data.archive_file.batch_cf_source.output_md5}.zip"
  bucket = google_storage_bucket.gcf_source_bucket.name
  source = data.archive_file.batch_cf_source.output_path
}

# 4. Cuenta de servicio dedicada para la Cloud Function
resource "google_service_account" "cf_batch_sa" {
  account_id   = "sa-batch-ingest"
  display_name = "Service Account para ingesta batch desde Storage a BQ"
}

# 5. Asignar Roles de Lectura de Storage e Ingesta en BigQuery
resource "google_storage_bucket_iam_member" "bronze_reader" {
  bucket = google_storage_bucket.bronze_raw_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cf_batch_sa.email}"
}

resource "google_project_iam_member" "batch_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.cf_batch_sa.email}"
}

resource "google_project_iam_member" "batch_bq_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.cf_batch_sa.email}"
}

resource "google_project_iam_member" "batch_eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.cf_batch_sa.email}"
}

# 6. Desplegar la Cloud Function Gen 2 vinculada con el disparador de GCS
resource "google_cloudfunctions2_function" "batch_gcs_to_bq_func" {
  name        = "batch-gcs-to-bq"
  location    = var.region
  description = "Pipeline Batch reactivo: Ingesta nativa de GCS a BigQuery"

  build_config {
    runtime     = "python311"
    entry_point = "ingest_gcs_to_bq"
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_source_bucket.name
        object = google_storage_bucket_object.batch_cf_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "512Mi"
    timeout_seconds    = 120 # Timeout extendido para cargas por lote más pesadas
    
    environment_variables = {
      DATASET_ID = google_bigquery_dataset.bronze_dataset.dataset_id
      TABLE_ID   = google_bigquery_table.orders_raw.table_id
    }
    
    service_account_email = google_service_account.cf_batch_sa.email
  }

  # Configuración del Trigger para cuando un objeto sea finalizado/creado en Storage
  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.storage.object.v1.finalized"
    service_account_email = google_service_account.cf_batch_sa.email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.bronze_raw_bucket.name
    }
  }

  depends_on = [
    google_project_iam_member.gcs_pubsub_publishing,
    google_storage_bucket_iam_member.bronze_reader,
    google_project_iam_member.batch_bq_editor,
    google_project_iam_member.batch_bq_user,
    google_project_iam_member.batch_eventarc_receiver,
    google_bigquery_table.orders_raw
  ]
}

# 7. Permitir llamadas públicas HTTP de prueba (Solo para desarrollo en este lab)
resource "google_cloud_run_service_iam_member" "public_invoker_batch" {
  location = google_cloudfunctions2_function.batch_gcs_to_bq_func.location
  service  = google_cloudfunctions2_function.batch_gcs_to_bq_func.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}