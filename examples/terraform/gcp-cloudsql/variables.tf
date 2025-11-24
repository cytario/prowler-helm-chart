# GCP Configuration
variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  type        = string
}

variable "gke_cluster_ca_certificate" {
  description = "GKE cluster CA certificate (base64 encoded)"
  type        = string
}

variable "gke_cluster_token" {
  description = "GKE cluster authentication token (optional if using exec)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vpc_network_name" {
  description = "VPC network name"
  type        = string
}

variable "vpc_network_id" {
  description = "VPC network ID for private service connection"
  type        = string
}

# Cloud SQL Configuration
variable "cloudsql_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "prowler-postgres"
}

variable "cloudsql_database_version" {
  description = "PostgreSQL database version"
  type        = string
  default     = "POSTGRES_16"
}

variable "cloudsql_tier" {
  description = "Cloud SQL tier (machine type)"
  type        = string
  default     = "db-custom-2-8192"
}

variable "cloudsql_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "cloudsql_availability_type" {
  description = "Availability type (REGIONAL or ZONAL)"
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "ZONAL"], var.cloudsql_availability_type)
    error_message = "Availability type must be REGIONAL or ZONAL."
  }
}

variable "cloudsql_database_name" {
  description = "Database name"
  type        = string
  default     = "prowler_db"
}

variable "cloudsql_user_name" {
  description = "Database user name"
  type        = string
  default     = "prowler"
}

variable "cloudsql_user_password" {
  description = "Database user password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudsql_backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "cloudsql_backup_start_time" {
  description = "Backup start time (HH:MM format)"
  type        = string
  default     = "03:00"
}

variable "cloudsql_pitr_enabled" {
  description = "Enable Point-in-Time Recovery"
  type        = bool
  default     = true
}

variable "cloudsql_retained_backups" {
  description = "Number of backups to retain"
  type        = number
  default     = 7
}

variable "cloudsql_insights_enabled" {
  description = "Enable Query Insights"
  type        = bool
  default     = true
}

variable "cloudsql_ipv4_enabled" {
  description = "Enable public IPv4 address"
  type        = bool
  default     = false
}

variable "cloudsql_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

# Prowler Configuration
variable "namespace" {
  description = "Kubernetes namespace to deploy Prowler"
  type        = string
  default     = "prowler"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "prowler"
}

variable "chart_version" {
  description = "Prowler Helm chart version"
  type        = string
  default     = "0.1.0"
}

variable "chart_path" {
  description = "Path to the Prowler Helm chart (use this for local chart)"
  type        = string
  default     = ""
}

variable "chart_repository" {
  description = "Helm chart repository URL"
  type        = string
  default     = ""
}

variable "api_replicas" {
  description = "Number of API replicas"
  type        = number
  default     = 2
}

variable "ui_replicas" {
  description = "Number of UI replicas"
  type        = number
  default     = 2
}

variable "worker_replicas" {
  description = "Number of Worker replicas"
  type        = number
  default     = 2
}

variable "labels" {
  description = "Labels to apply to GCP resources"
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    application = "prowler"
  }
}
