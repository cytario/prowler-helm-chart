output "release_name" {
  description = "The name of the Helm release"
  value       = helm_release.prowler.name
}

output "release_namespace" {
  description = "The namespace where Prowler is deployed"
  value       = helm_release.prowler.namespace
}

output "release_status" {
  description = "The status of the Helm release"
  value       = helm_release.prowler.status
}

output "release_version" {
  description = "The version of the Helm release"
  value       = helm_release.prowler.version
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
