# Generate random password if not provided
resource "random_password" "cloudsql" {
  count   = var.cloudsql_user_password == "" ? 1 : 0
  length  = 32
  special = true
}

locals {
  cloudsql_password = var.cloudsql_user_password != "" ? var.cloudsql_user_password : random_password.cloudsql[0].result
}

# Allocate IP range for private service connection
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.cloudsql_instance_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network_id
}

# Create private VPC connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "prowler" {
  name             = var.cloudsql_instance_name
  database_version = var.cloudsql_database_version
  region           = var.gcp_region

  deletion_protection = var.cloudsql_deletion_protection

  settings {
    tier              = var.cloudsql_tier
    availability_type = var.cloudsql_availability_type
    disk_size         = var.cloudsql_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = var.cloudsql_backup_enabled
      start_time                     = var.cloudsql_backup_start_time
      point_in_time_recovery_enabled = var.cloudsql_pitr_enabled
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.cloudsql_retained_backups
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = var.cloudsql_ipv4_enabled
      private_network = var.vpc_network_id
      require_ssl     = true
    }

    insights_config {
      query_insights_enabled  = var.cloudsql_insights_enabled
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    user_labels = var.labels
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Cloud SQL Database
resource "google_sql_database" "prowler" {
  name     = var.cloudsql_database_name
  instance = google_sql_database_instance.prowler.name
}

# Cloud SQL User
resource "google_sql_user" "prowler" {
  name     = var.cloudsql_user_name
  instance = google_sql_database_instance.prowler.name
  password = local.cloudsql_password
}

# Create namespace
resource "kubernetes_namespace" "prowler" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "prowler"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Create Kubernetes secret with Cloud SQL credentials
resource "kubernetes_secret" "cloudsql" {
  metadata {
    name      = "prowler-cloudsql-postgres"
    namespace = var.namespace
  }

  data = {
    POSTGRES_HOST           = google_sql_database_instance.prowler.private_ip_address
    POSTGRES_PORT           = "5432"
    POSTGRES_ADMIN_USER     = var.cloudsql_user_name
    POSTGRES_ADMIN_PASSWORD = local.cloudsql_password
    POSTGRES_USER           = var.cloudsql_user_name
    POSTGRES_PASSWORD       = local.cloudsql_password
    POSTGRES_DB             = var.cloudsql_database_name
  }

  depends_on = [
    kubernetes_namespace.prowler,
    google_sql_database_instance.prowler,
    google_sql_database.prowler,
    google_sql_user.prowler
  ]
}

# Deploy Prowler Helm Chart with Cloud SQL
resource "helm_release" "prowler" {
  name             = var.release_name
  chart            = var.chart_path != "" ? var.chart_path : "prowler"
  repository       = var.chart_path != "" ? null : var.chart_repository
  version          = var.chart_path != "" ? null : var.chart_version
  namespace        = var.namespace
  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [
    kubernetes_namespace.prowler,
    google_sql_database_instance.prowler,
    kubernetes_secret.cloudsql
  ]

  # Disable internal PostgreSQL
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # Configure external Cloud SQL secret for API
  set {
    name  = "api.secrets[0]"
    value = kubernetes_secret.cloudsql.metadata[0].name
  }

  # Configure external Cloud SQL secret for Worker
  set {
    name  = "worker.secrets[0]"
    value = kubernetes_secret.cloudsql.metadata[0].name
  }

  # Configure external Cloud SQL secret for Worker Beat
  set {
    name  = "worker_beat.secrets[0]"
    value = kubernetes_secret.cloudsql.metadata[0].name
  }

  # Valkey Configuration
  set {
    name  = "valkey.enabled"
    value = "true"
  }

  set {
    name  = "valkey.dataStorage.enabled"
    value = "false"
  }

  # API Configuration
  set {
    name  = "api.replicaCount"
    value = var.api_replicas
  }

  # UI Configuration
  set {
    name  = "ui.replicaCount"
    value = var.ui_replicas
  }

  # Worker Configuration
  set {
    name  = "worker.replicaCount"
    value = var.worker_replicas
  }
}
