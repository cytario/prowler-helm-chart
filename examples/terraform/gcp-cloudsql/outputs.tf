output "cloudsql_instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.prowler.name
}

output "cloudsql_instance_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.prowler.connection_name
}

output "cloudsql_private_ip_address" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.prowler.private_ip_address
}

output "cloudsql_public_ip_address" {
  description = "The public IP address of the Cloud SQL instance (if enabled)"
  value       = var.cloudsql_ipv4_enabled ? google_sql_database_instance.prowler.public_ip_address : null
}

output "cloudsql_database_name" {
  description = "The database name"
  value       = google_sql_database.prowler.name
}

output "cloudsql_user_name" {
  description = "The database user name"
  value       = google_sql_user.prowler.name
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

output "cloudsql_secret_name" {
  description = "The name of the Kubernetes secret containing Cloud SQL credentials"
  value       = kubernetes_secret.cloudsql.metadata[0].name
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

output "cloudsql_connection_info" {
  description = "Cloud SQL connection information"
  value = {
    connection_name      = google_sql_database_instance.prowler.connection_name
    private_ip_address   = google_sql_database_instance.prowler.private_ip_address
    port                 = 5432
    database             = var.cloudsql_database_name
    username             = var.cloudsql_user_name
  }
  sensitive = false
}

output "cloudsql_features" {
  description = "Cloud SQL features configuration"
  value = {
    availability_type         = var.cloudsql_availability_type
    point_in_time_recovery   = var.cloudsql_pitr_enabled
    query_insights_enabled   = var.cloudsql_insights_enabled
    backup_enabled           = var.cloudsql_backup_enabled
    retained_backups         = var.cloudsql_retained_backups
  }
}
