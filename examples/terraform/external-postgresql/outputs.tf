output "prowler_release_name" {
  description = "The name of the Prowler Helm release"
  value       = helm_release.prowler.name
}

output "postgres_release_name" {
  description = "The name of the PostgreSQL Helm release"
  value       = helm_release.postgresql.name
}

output "release_namespace" {
  description = "The namespace where resources are deployed"
  value       = helm_release.prowler.namespace
}

output "prowler_release_status" {
  description = "The status of the Prowler Helm release"
  value       = helm_release.prowler.status
}

output "postgres_release_status" {
  description = "The status of the PostgreSQL Helm release"
  value       = helm_release.postgresql.status
}

output "postgres_service_name" {
  description = "The PostgreSQL service name"
  value       = "${var.postgres_release_name}-postgresql.${var.namespace}.svc.cluster.local"
}

output "postgres_secret_name" {
  description = "The name of the Kubernetes secret containing PostgreSQL credentials"
  value       = kubernetes_secret.postgres_external.metadata[0].name
}

output "ui_access_command" {
  description = "Command to access Prowler UI via port-forward"
  value       = "kubectl port-forward -n ${var.namespace} svc/${var.release_name}-ui 3000:3000"
}

output "api_access_command" {
  description = "Command to access Prowler API via port-forward"
  value       = "kubectl port-forward -n ${var.namespace} svc/${var.release_name}-api 8080:8080"
}

output "postgres_access_command" {
  description = "Command to access PostgreSQL via port-forward"
  value       = "kubectl port-forward -n ${var.namespace} svc/${var.postgres_release_name}-postgresql 5432:5432"
}

output "api_docs_url" {
  description = "URL to access API documentation (after port-forward)"
  value       = "http://localhost:8080/api/v1/docs"
}

output "ui_url" {
  description = "URL to access UI (after port-forward)"
  value       = "http://localhost:3000"
}

output "postgres_connection_info" {
  description = "PostgreSQL connection information"
  value = {
    host     = "${var.postgres_release_name}-postgresql.${var.namespace}.svc.cluster.local"
    port     = 5432
    database = var.postgres_database
    username = var.postgres_username
  }
  sensitive = false
}
