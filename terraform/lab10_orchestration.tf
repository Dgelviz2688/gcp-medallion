# 1. Habilitar la API de Cloud Workflows
resource "google_project_service" "workflows_api" {
  project            = var.project_id
  service            = "workflows.googleapis.com"
  disable_on_destroy = false
}

# 2. Cuenta de Servicio dedicada para el Orquestador
resource "google_service_account" "workflows_sa" {
  account_id   = "sa-medallion-orchestrator"
  display_name = "Service Account para Orquestador de Cloud Workflows"
}

# 3. Permisos para que el orquestador ejecute queries y jobs en BigQuery
resource "google_project_iam_member" "workflows_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

resource "google_project_iam_member" "workflows_bq_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# 4. Permisos para invocar la Cloud Function de Ingesta API
resource "google_cloud_run_service_iam_member" "workflows_cf_invoker" {
  location = google_cloudfunctions2_function.ingest_api_function.location
  service  = google_cloudfunctions2_function.ingest_api_function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# Permisos para que el orquestador escriba logs (requerido por sys.log)
resource "google_project_iam_member" "workflows_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# 5. Desplegar el Orquestador inyectando variables dinámicamente usando templatefile
resource "google_workflows_workflow" "medallion_orchestrator" {
  name            = "medallion-orchestrator"
  region          = var.region
  description     = "Orquestador serverless de la arquitectura Medallion"
  service_account = google_service_account.workflows_sa.email

  source_contents = templatefile("${path.module}/../workflows/medallion_workflow.yaml", {
    project_id = var.project_id
    api_cf_url = google_cloudfunctions2_function.ingest_api_function.service_config[0].uri
  })

  depends_on = [
    google_project_service.workflows_api,
    google_project_iam_member.workflows_bq_job_user,
    google_project_iam_member.workflows_bq_data_editor,
    google_cloud_run_service_iam_member.workflows_cf_invoker,
    google_project_iam_member.workflows_log_writer 
  ]
}