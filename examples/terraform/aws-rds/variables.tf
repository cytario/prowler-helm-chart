# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64 encoded)"
  type        = string
}

variable "eks_cluster_token" {
  description = "EKS cluster authentication token (optional if using exec)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_subnet_ids" {
  description = "List of subnet IDs for RDS subnet group"
  type        = list(string)
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 100
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage for RDS autoscaling in GB"
  type        = number
  default     = 500
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "rds_database_name" {
  description = "Database name"
  type        = string
  default     = "prowler_db"
}

variable "rds_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "prowler_admin"
}

variable "rds_master_password" {
  description = "Master password for RDS (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "rds_storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "rds_performance_insights_enabled" {
  description = "Enable Performance Insights"
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

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Application = "prowler"
  }
}
