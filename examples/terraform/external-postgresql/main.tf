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

# Deploy PostgreSQL separately
resource "helm_release" "postgresql" {
  name             = var.postgres_release_name
  chart            = "postgresql"
  repository       = "https://charts.bitnami.com/bitnami"
  version          = var.postgres_version
  namespace        = var.namespace
  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [kubernetes_namespace.prowler]

  set_sensitive {
    name  = "global.postgresql.auth.postgresPassword"
    value = var.postgres_admin_password
  }

  set {
    name  = "global.postgresql.auth.database"
    value = var.postgres_database
  }

  set {
    name  = "global.postgresql.auth.username"
    value = var.postgres_username
  }

  set_sensitive {
    name  = "global.postgresql.auth.password"
    value = var.postgres_app_password
  }

  set {
    name  = "primary.persistence.enabled"
    value = var.enable_postgres_persistence
  }

  dynamic "set" {
    for_each = var.storage_class != "" && var.enable_postgres_persistence ? [1] : []
    content {
      name  = "primary.persistence.storageClass"
      value = var.storage_class
    }
  }
}

# Create Kubernetes secret with external PostgreSQL credentials
resource "kubernetes_secret" "postgres_external" {
  metadata {
    name      = "prowler-external-postgres"
    namespace = var.namespace
  }

  data = {
    POSTGRES_HOST           = "${var.postgres_release_name}-postgresql.${var.namespace}.svc.cluster.local"
    POSTGRES_PORT           = "5432"
    POSTGRES_ADMIN_USER     = "postgres"
    POSTGRES_ADMIN_PASSWORD = var.postgres_admin_password
    POSTGRES_USER           = var.postgres_username
    POSTGRES_PASSWORD       = var.postgres_app_password
    POSTGRES_DB             = var.postgres_database
  }

  depends_on = [
    kubernetes_namespace.prowler,
    helm_release.postgresql
  ]
}

# Deploy Prowler Helm Chart with external PostgreSQL
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
    helm_release.postgresql,
    kubernetes_secret.postgres_external
  ]

  # Disable internal PostgreSQL
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # Configure external PostgreSQL secret for API
  set {
    name  = "api.secrets[0]"
    value = kubernetes_secret.postgres_external.metadata[0].name
  }

  # Configure external PostgreSQL secret for Worker
  set {
    name  = "worker.secrets[0]"
    value = kubernetes_secret.postgres_external.metadata[0].name
  }

  # Configure external PostgreSQL secret for Worker Beat
  set {
    name  = "worker_beat.secrets[0]"
    value = kubernetes_secret.postgres_external.metadata[0].name
  }

  # Valkey Configuration
  set {
    name  = "valkey.enabled"
    value = "true"
  }

  set {
    name  = "valkey.dataStorage.enabled"
    value = var.enable_valkey_persistence
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
