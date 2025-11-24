# Generate random password if not provided
resource "random_password" "postgres" {
  count   = var.postgres_admin_password == "" ? 1 : 0
  length  = 32
  special = true
}

locals {
  postgres_password = var.postgres_admin_password != "" ? var.postgres_admin_password : random_password.postgres[0].result
}

# Azure PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "prowler" {
  name                = var.postgres_server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  version      = var.postgres_version
  sku_name     = var.postgres_sku_name
  storage_mb   = var.postgres_storage_mb
  storage_tier = "P30"

  administrator_login    = var.postgres_admin_username
  administrator_password = local.postgres_password

  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = var.postgres_geo_redundant_backup

  dynamic "high_availability" {
    for_each = var.postgres_high_availability != "" ? [1] : []
    content {
      mode = var.postgres_high_availability
    }
  }

  delegated_subnet_id = var.subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  zone = "1"

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.postgres_server_name}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.postgres_server_name}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.vnet_id

  tags = var.tags
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "prowler" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.prowler.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Configuration
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.prowler.id
  value     = "pg_stat_statements"
}

# Firewall rule to allow Azure services (optional)
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.prowler.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
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

# Create Kubernetes secret with PostgreSQL credentials
resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "prowler-azure-postgres"
    namespace = var.namespace
  }

  data = {
    POSTGRES_HOST           = azurerm_postgresql_flexible_server.prowler.fqdn
    POSTGRES_PORT           = "5432"
    POSTGRES_ADMIN_USER     = var.postgres_admin_username
    POSTGRES_ADMIN_PASSWORD = local.postgres_password
    POSTGRES_USER           = var.postgres_admin_username
    POSTGRES_PASSWORD       = local.postgres_password
    POSTGRES_DB             = var.postgres_database_name
  }

  depends_on = [
    kubernetes_namespace.prowler,
    azurerm_postgresql_flexible_server.prowler,
    azurerm_postgresql_flexible_server_database.prowler
  ]
}

# Deploy Prowler Helm Chart with Azure PostgreSQL
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
    azurerm_postgresql_flexible_server.prowler,
    kubernetes_secret.postgres
  ]

  # Disable internal PostgreSQL
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # Configure external PostgreSQL secret for API
  set {
    name  = "api.secrets[0]"
    value = kubernetes_secret.postgres.metadata[0].name
  }

  # Configure external PostgreSQL secret for Worker
  set {
    name  = "worker.secrets[0]"
    value = kubernetes_secret.postgres.metadata[0].name
  }

  # Configure external PostgreSQL secret for Worker Beat
  set {
    name  = "worker_beat.secrets[0]"
    value = kubernetes_secret.postgres.metadata[0].name
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
