variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = ""
}

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
  description = "Helm release name for Prowler"
  type        = string
  default     = "prowler"
}

variable "postgres_release_name" {
  description = "Helm release name for PostgreSQL"
  type        = string
  default     = "prowler-postgres"
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

variable "postgres_admin_password" {
  description = "PostgreSQL admin (postgres user) password"
  type        = string
  sensitive   = true
}

variable "postgres_app_password" {
  description = "PostgreSQL application user password"
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "prowler_db"
}

variable "postgres_username" {
  description = "PostgreSQL application username"
  type        = string
  default     = "prowler"
}

variable "postgres_version" {
  description = "PostgreSQL Helm chart version"
  type        = string
  default     = "18.1.4"
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

variable "enable_postgres_persistence" {
  description = "Enable persistent storage for PostgreSQL"
  type        = bool
  default     = true
}

variable "enable_valkey_persistence" {
  description = "Enable persistent storage for Valkey"
  type        = bool
  default     = false
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = ""
}
