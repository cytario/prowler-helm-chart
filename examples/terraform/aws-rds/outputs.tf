output "rds_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.prowler.id
}

output "rds_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.prowler.arn
}

output "rds_endpoint" {
  description = "The connection endpoint"
  value       = aws_db_instance.prowler.endpoint
}

output "rds_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.prowler.address
}

output "rds_port" {
  description = "The port the DB is listening on"
  value       = aws_db_instance.prowler.port
}

output "rds_database_name" {
  description = "The database name"
  value       = aws_db_instance.prowler.db_name
}

output "rds_master_username" {
  description = "The master username"
  value       = aws_db_instance.prowler.username
  sensitive   = true
}

output "rds_security_group_id" {
  description = "The security group ID for RDS"
  value       = aws_security_group.rds.id
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

output "rds_secret_name" {
  description = "The name of the Kubernetes secret containing RDS credentials"
  value       = kubernetes_secret.rds.metadata[0].name
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

output "rds_connection_info" {
  description = "RDS connection information"
  value = {
    endpoint = aws_db_instance.prowler.endpoint
    address  = aws_db_instance.prowler.address
    port     = aws_db_instance.prowler.port
    database = aws_db_instance.prowler.db_name
    username = aws_db_instance.prowler.username
  }
  sensitive = false
}

output "rds_monitoring" {
  description = "RDS monitoring information"
  value = {
    performance_insights_enabled = var.rds_performance_insights_enabled
    cloudwatch_logs             = aws_db_instance.prowler.enabled_cloudwatch_logs_exports
    enhanced_monitoring_role    = aws_iam_role.rds_monitoring.arn
  }
}
