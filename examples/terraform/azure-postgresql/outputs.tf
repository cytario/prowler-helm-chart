output "postgres_server_id" {
  description = "The ID of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.prowler.id
}

output "postgres_server_fqdn" {
  description = "The FQDN of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.prowler.fqdn
}

output "postgres_server_name" {
  description = "The name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.prowler.name
}

output "postgres_database_name" {
  description = "The database name"
  value       = azurerm_postgresql_flexible_server_database.prowler.name
}

output "postgres_admin_username" {
  description = "The PostgreSQL admin username"
  value       = var.postgres_admin_username
  sensitive   = true
}

output "prowler_release_name" {
  description = "The name of the Prowler Helm release"
  value       = helm_release.prowler.name
}

output "prowler_namespace" {
  description = "The namespace where Prowler is deployed"
  value       = helm_release.prowler.namespace
}

output "prowler_release_status" {
  description = "The status of the Prowler Helm release"
  value       = helm_release.prowler.status
}

output "postgres_secret_name" {
  description = "The name of the Kubernetes secret containing PostgreSQL credentials"
  value       = kubernetes_secret.postgres.metadata[0].name
}

output "ui_access_command" {
  description = "Command to access Prowler UI via port-forward"
  value       = "kubectl port-forward -n ${var.namespace} svc/${var.release_name}-ui 3000:3000"
}

output "api_access_command" {
  description = "Command to access Prowler API via port-forward"
  value       = "kubectl port-forward -n ${var.namespace} svc/${var.release_name}-api 8080:8080"
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
    fqdn     = azurerm_postgresql_flexible_server.prowler.fqdn
    port     = 5432
    database = var.postgres_database_name
    username = var.postgres_admin_username
  }
  sensitive = false
}

output "postgres_high_availability" {
  description = "PostgreSQL High Availability configuration"
  value = {
    enabled = var.postgres_high_availability != ""
    mode    = var.postgres_high_availability
  }
}
