output "bucket_url" {
  description = "URL of the uploads bucket"
  value       = google_storage_bucket.uploads.url
}

output "process_document_function_url" {
  description = "URL of the document processing Cloud Function"
  value       = google_cloudfunctions2_function.process_document.url
}

output "check_anomalies_function_url" {
  description = "URL of the anomaly detection Cloud Function"
  value       = google_cloudfunctions2_function.check_anomalies.url
}

output "bigquery_dataset" {
  description = "BigQuery dataset for processed documents"
  value       = google_bigquery_dataset.watchdog_data.dataset_id
}
