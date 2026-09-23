# 1. Comprimir el código fuente de la función
data "archive_file" "cf_source" {
  type        = "zip"
  source_dir  = "${path.module}/../src/ingest_api"
  output_path = "${path.module}/files/ingest_api.zip"
}

# 2. Bucket para almacenar el código fuente empaquetado de las Cloud Functions
resource "google_storage_bucket" "gcf_source_bucket" {
  name                        = "${var.project_id}-gcf-sources"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.services]
}

# 3. Subir el ZIP generado al bucket de fuentes
resource "google_storage_bucket_object" "cf_source_zip" {
  name   = "ingest_api_${data.archive_file.cf_source.output_md5}.zip" # Usar hash MD5 evita redespliegues si el código no cambia
  bucket = google_storage_bucket.gcf_source_bucket.name
  source = data.archive_file.cf_source.output_path
}

# 4. Crear Cuenta de Servicio dedicada para la Cloud Function (Principio de mínimo privilegio)
resource "google_service_account" "cf_service_account" {
  account_id   = "sa-ingest-api"
  display_name = "Service Account para Cloud Function de Ingesta API"
  depends_on   = [google_project_service.services]
}

# 5. Otorgar permisos a la Cuenta de Servicio para escribir en el bucket de capa Bronze
resource "google_storage_bucket_iam_member" "bronze_writer" {
  bucket = google_storage_bucket.bronze_raw_bucket.name
  role   = "roles/storage.objectUser" # Permite leer, escribir y borrar objetos
  member = "serviceAccount:${google_service_account.cf_service_account.email}"
}

# 6. Desplegar la Cloud Function (Segunda Generación)
resource "google_cloudfunctions2_function" "ingest_api_function" {
  name        = "ingest-api-to-bronze"
  location    = var.region
  description = "Función que extrae datos de API REST y los guarda en GCS Bronze Raw"

  build_config {
    runtime     = "python311"
    entry_point = "ingest_api_data" # Debe coincidir con el nombre de la función en main.py
    source {
      storage_source {
        bucket = google_storage_bucket.gcf_source_bucket.name
        object = google_storage_bucket_object.cf_source_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "512Mi"
    timeout_seconds    = 60
    
    # Inyectamos el nombre del bucket de la capa Bronze como variable de entorno
    environment_variables = {
      BUCKET_NAME = google_storage_bucket.bronze_raw_bucket.name
    }
    
    # Asignamos la Service Account que creamos
    service_account_email = google_service_account.cf_service_account.email
  }

  depends_on = [
    google_storage_bucket_iam_member.bronze_writer
  ]
}

# 7. Permitir llamadas públicas HTTP de prueba (Solo para desarrollo en este lab)
resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = google_cloudfunctions2_function.ingest_api_function.location
  service  = google_cloudfunctions2_function.ingest_api_function.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}