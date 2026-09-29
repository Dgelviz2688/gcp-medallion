data "google_project" "current" {
  project_id = var.project_id
}

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-pool"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # 1. Map the provider's OIDC claims to Google attributes
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # 2. Add the mandatory attribute condition
  # This restricts authentication ONLY to repositories belonging to your GitHub Org or User
  attribute_condition = "assertion.repository_owner == 'Dgelviz2688'"
}

# 3. Crear Cuenta de Servicio dedicada para el Runner de GitHub
resource "google_service_account" "github_actions_sa" {
  account_id   = "sa-github-actions-runner"
  display_name = "Service Account para ejecuciones del runner de GitHub"
}

# 4. Asignar rol de Editor para que el runner pueda aprovisionar infraestructura
resource "google_project_iam_member" "github_editor_binding" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# 5. Enlazar el repositorio de GitHub con la cuenta de servicio (Impersonation)
# Esto autoriza únicamente a tu repositorio a suplantar a la SA
resource "google_service_account_iam_member" "github_sa_impersonation" {
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"

  # Forzamos el uso del número de proyecto en el principalSet
  member = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}


# Salidas necesarias para configurar GitHub Secrets

output "gcp_wif_provider" {
  value       = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id}"
  description = "Valor exacto para el secreto GCP_WIF_PROVIDER en GitHub"
}

output "gcp_sa_email" {
  value       = google_service_account.github_actions_sa.email
  description = "Valor exacto para el secreto GCP_SA_EMAIL en GitHub"
}