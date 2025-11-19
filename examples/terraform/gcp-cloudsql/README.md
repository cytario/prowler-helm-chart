# Prowler with GCP Cloud SQL PostgreSQL using Terraform

This example demonstrates deploying Prowler on GKE with Cloud SQL for PostgreSQL.

## Architecture

Cloud SQL PostgreSQL instance + GKE cluster with Prowler pods connecting via private IP or Cloud SQL Proxy.

## Key Files

Create these files:
- `versions.tf` - GCP and Kubernetes providers
- `variables.tf` - Configuration variables
- `main.tf` - Cloud SQL + Prowler deployment
- `outputs.tf` - Connection information
- `terraform.tfvars.example` - Example configuration

## Quick Start

```bash
# 1. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit with your GKE cluster info and project ID

# 2. Initialize and apply
terraform init
terraform apply

# 3. Access Prowler
kubectl port-forward -n prowler svc/prowler-ui 3000:3000
```

## Key Configuration

```hcl
# Cloud SQL PostgreSQL
resource "google_sql_database_instance" "prowler" {
  name             = "prowler-postgres"
  database_version = "POSTGRES_16"
  region           = var.gcp_region

  settings {
    tier              = "db-custom-2-8192"
    availability_type = "REGIONAL"
    disk_size         = 100
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network_id
    }
  }
}

# Prowler with external database
resource "helm_release" "prowler" {
  name  = "prowler"
  chart = "../../../charts/prowler"

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "api.secrets[0]"
    value = kubernetes_secret.cloudsql.metadata[0].name
  }
}
```

## Connection Methods

### Method 1: Private IP (Recommended)

```hcl
# Direct connection via VPC peering
ip_configuration {
  ipv4_enabled    = false
  private_network = var.vpc_network_id
}
```

### Method 2: Cloud SQL Proxy

```yaml
# Add sidecar container to API/Worker pods
- name: cloud-sql-proxy
  image: gcr.io/cloudsql-docker/gce-proxy:latest
  command:
    - "/cloud_sql_proxy"
    - "-instances=PROJECT:REGION:INSTANCE=tcp:5432"
```

## Features

- **Regional HA**: Automatic failover within region
- **Point-in-Time Recovery**: Restore to any second
- **Private IP**: Secure VPC-native connectivity
- **Automated Backups**: Daily backups with retention
- **IAM Authentication**: Optional IAM-based auth
- **Query Insights**: Performance monitoring built-in

## Cost Estimate (GCP)

- db-custom-2-8192 (Regional HA): ~$200/month
- Storage (100GB SSD): ~$20/month
- Backup storage: ~$5/month
- **Total**: ~$225-250/month

## Production Checklist

- [ ] Regional availability enabled
- [ ] Point-in-time recovery enabled
- [ ] Private IP configured (no public IP)
- [ ] Automatic backups enabled (7+ days)
- [ ] Query Insights enabled
- [ ] SSL enforcement enabled
- [ ] VPC firewall rules configured
- [ ] Cloud Monitoring alerts configured

## Documentation

- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)
