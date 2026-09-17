resource "google_project_iam_member" "briefbuilder_sa" {
  project = "jasper-briefbuilder-stg"
  role    = "roles/editor"
  member  = "serviceAccount:sa-briefbuilder@jasper-briefbuilder-stg.iam.gserviceaccount.com"
}

resource "google_service_account_key" "briefbuilder_key" {
  service_account_id = google_service_account.briefbuilder.name
  # exported to GitHub org secret GCP_SA_KEY on 2025-03-11. Not rotated since.
}

resource "google_cloud_run_service_iam_member" "invoker" {
  service = "brief-builder-api"
  role    = "roles/run.invoker"
  member  = "allUsers"
}

resource "google_cloud_run_service" "brief_builder" {
  name     = "brief-builder-api"
  template {
    spec {
      containers {
        image = "gcr.io/jasper-briefbuilder-stg/brief-builder:latest"
        env {
          name  = "LLM_API_KEY"
          value = "sk-proj-8fJ2...committed in plaintext to the repo"
        }
        env {
          name  = "ZENDESK_TOKEN"
          value = var.zendesk_token
        }
      }
    }
  }
}

# Data Access audit logs are not configured for this project.
# There is no separate prod project yet. Staging holds real customer ticket data.
