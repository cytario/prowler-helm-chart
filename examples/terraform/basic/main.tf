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

# Deploy Prowler Helm Chart
resource "helm_release" "prowler" {
  name             = var.release_name
  chart            = var.chart_path != "" ? var.chart_path : "prowler"
  repository       = var.chart_path != "" ? null : var.chart_repository
  version          = var.chart_path != "" ? null : var.chart_version
  namespace        = var.namespace
  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [kubernetes_namespace.prowler]

  # PostgreSQL Configuration
  set_sensitive {
    name  = "postgresql.global.postgresql.auth.postgresPassword"
    value = var.postgres_password
  }

  set {
    name  = "postgresql.enabled"
    value = "true"
  }

  set {
    name  = "postgresql.primary.persistence.enabled"
    value = var.enable_persistence
  }

  dynamic "set" {
    for_each = var.storage_class != "" ? [1] : []
    content {
      name  = "postgresql.primary.persistence.storageClass"
      value = var.storage_class
    }
  }

  # Valkey Configuration
  set {
    name  = "valkey.enabled"
    value = "true"
  }

  set {
    name  = "valkey.dataStorage.enabled"
    value = var.enable_persistence
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
