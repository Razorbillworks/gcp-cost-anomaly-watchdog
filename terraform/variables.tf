variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "cloud-cost-watchdog-502507"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "asia-south1"
}

variable "bucket_name" {
  description = "Cloud Storage bucket name for document uploads"
  type        = string
  default     = "cloud-cost-watchdog-uploads-razorbill"
}

variable "billing_account_id" {
  description = "GCP Billing Account ID"
  type        = string
  # Set this via terraform.tfvars or -var flag; not hardcoded for security
}
