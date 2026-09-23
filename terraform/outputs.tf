output "bronze_bucket_name" {
  value       = google_storage_bucket.bronze_raw_bucket.name
  description = "Nombre del bucket de almacenamiento Bronze"
}

output "firestore_database_name" {
  value       = google_firestore_database.firestore_db.name
  description = "Nombre de la base de datos Firestore inicializada"
}

output "cloud_function_url" {
  value       = google_cloudfunctions2_function.ingest_api_function.service_config[0].uri
  description = "URL HTTP pública para disparar la Cloud Function de ingesta"
}

output "firestore_to_bq_function_url" {
  value       = google_cloudfunctions2_function.firestore_to_bq_func.service_config[0].uri
  description = "URL HTTP pública para disparar la Cloud Function de ingesta desde Firestore"
}