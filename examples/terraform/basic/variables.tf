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

variable "postgres_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
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

variable "enable_persistence" {
  description = "Enable persistent storage for PostgreSQL and Valkey"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = ""
}
