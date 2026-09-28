# 1. Crear el dataset de Cuarentena
resource "google_bigquery_dataset" "quarantine_dataset" {
  dataset_id  = "quarantine"
  description = "Capa de Cuarentena para datos que no cumplen las reglas de calidad"
  location    = var.bq_location
  depends_on  = [google_project_service.services]
}

# 2. Crear Tabla Unificada de Errores/Registros Inválidos
resource "google_bigquery_table" "invalid_records" {
  dataset_id          = google_bigquery_dataset.quarantine_dataset.dataset_id
  table_id            = "invalid_records"
  deletion_protection = false

  schema = <<EOF
[
  {
    "name": "table_name",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Tabla origen del fallo (customers, orders)"
  },
  {
    "name": "record_key",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Clave primaria del registro que falló"
  },
  {
    "name": "error_reason",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Descripción de la regla de calidad que se violó"
  },
  {
    "name": "rejected_payload",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Payload original serializado del registro corrupto"
  },
  {
    "name": "rejected_at",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Fecha y hora en la que fue detectado y rechazado"
  }
]
EOF
}