terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Cloud Storage bucket for document uploads
resource "google_storage_bucket" "uploads" {
  name                         = var.bucket_name
  location                     = var.region
  storage_class                = "STANDARD"
  uniform_bucket_level_access  = true
  public_access_prevention     = "enforced"

  soft_delete_policy {
    retention_duration_seconds = 604800 # 7 days
  }
}

# BigQuery dataset for document processing results
resource "google_bigquery_dataset" "watchdog_data" {
  dataset_id = "watchdog_data"
  location   = var.region
}

# BigQuery table schema for processed documents
resource "google_bigquery_table" "processed_documents" {
  dataset_id = google_bigquery_dataset.watchdog_data.dataset_id
  table_id   = "processed_documents"

  schema = jsonencode([
    { name = "file_name", type = "STRING", mode = "NULLABLE" },
    { name = "extracted_text", type = "STRING", mode = "NULLABLE" },
    { name = "detected_language", type = "STRING", mode = "NULLABLE" },
    { name = "translated_text", type = "STRING", mode = "NULLABLE" },
    { name = "processed_at", type = "TIMESTAMP", mode = "NULLABLE" }
  ])
}

# BigQuery dataset for billing export
resource "google_bigquery_dataset" "billing_export" {
  dataset_id = "billing_export"
  location   = var.region
}

# Cloud Function: document processing pipeline (OCR + Translation + BigQuery)
resource "google_cloudfunctions2_function" "process_document" {
  name     = "process-document"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "process_document"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "process-document-source.zip"
      }
    }
  }

  service_config {
    available_memory = "512M"
    timeout_seconds   = 120
  }

  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.uploads.name
    }
  }
}

# Cloud Function: scheduled anomaly detection
resource "google_cloudfunctions2_function" "check_anomalies" {
  name     = "check-anomalies"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "check_anomalies"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = "check-anomalies-source.zip"
      }
    }
  }

  service_config {
    available_memory = "256M"
    timeout_seconds   = 60
  }
}

# Bucket to hold zipped function source code (required for Terraform-managed deployments)
resource "google_storage_bucket" "function_source" {
  name                         = "${var.project_id}-function-source"
  location                     = var.region
  uniform_bucket_level_access  = true
}

# Cloud Scheduler job to trigger anomaly check daily
resource "google_cloud_scheduler_job" "daily_anomaly_check" {
  name      = "daily-anomaly-check"
  region    = var.region
  schedule  = "0 9 * * *"
  time_zone = "Asia/Kolkata"

  http_target {
    uri         = google_cloudfunctions2_function.check_anomalies.url
    http_method = "POST"
  }
}

# Budget alert
resource "google_billing_budget" "watchdog_budget" {
  billing_account = var.billing_account_id
  display_name    = "Watchdog Safety Budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "INR"
      units         = "50"
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}
