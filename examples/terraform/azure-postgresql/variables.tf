# Azure Configuration
variable "resource_group_name" {
  description = "Azure Resource Group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_cluster_endpoint" {
  description = "AKS cluster endpoint"
  type        = string
}

variable "aks_client_certificate" {
  description = "AKS client certificate (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "aks_client_key" {
  description = "AKS client key (base64 encoded)"
  type        = string
  sensitive   = true
}

variable "aks_cluster_ca_certificate" {
  description = "AKS cluster CA certificate (base64 encoded)"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID for private endpoint"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for PostgreSQL delegation"
  type        = string
}

# PostgreSQL Configuration
variable "postgres_server_name" {
  description = "PostgreSQL Flexible Server name"
  type        = string
  default     = "prowler-postgres"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

variable "postgres_database_name" {
  description = "Database name"
  type        = string
  default     = "prowler_db"
}

variable "postgres_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "prowleradmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgres_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "postgres_geo_redundant_backup" {
  description = "Enable geo-redundant backup"
  type        = bool
  default     = true
}

variable "postgres_high_availability" {
  description = "Enable high availability (ZoneRedundant or SameZone)"
  type        = string
  default     = "ZoneRedundant"
  validation {
    condition     = contains(["ZoneRedundant", "SameZone", ""], var.postgres_high_availability)
    error_message = "High availability must be ZoneRedundant, SameZone, or empty string for disabled."
  }
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

variable "tags" {
  description = "Tags to apply to Azure resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Application = "prowler"
  }
}
