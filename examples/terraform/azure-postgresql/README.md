# Prowler with Azure Database for PostgreSQL using Terraform

This example demonstrates deploying Prowler on AKS with Azure Database for PostgreSQL Flexible Server.

## Architecture

Azure Database for PostgreSQL Flexible Server + AKS cluster with Prowler pods connecting via private endpoint.

## Key Files

Create these files:
- `versions.tf` - Azure and Kubernetes providers
- `variables.tf` - Configuration variables
- `main.tf` - Azure PostgreSQL + Prowler deployment
- `outputs.tf` - Connection information
- `terraform.tfvars.example` - Example configuration

## Quick Start

```bash
# 1. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit with your AKS cluster info and resource group

# 2. Initialize and apply
terraform init
terraform apply

# 3. Access Prowler
kubectl port-forward -n prowler svc/prowler-ui 3000:3000
```

## Key Configuration

```hcl
# Azure PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "prowler" {
  name                = "prowler-postgres"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name   = "GP_Standard_D2s_v3"
  version    = "16"
  storage_mb = 32768

  backup_retention_days = 7
  geo_redundant_backup_enabled = true

  high_availability {
    mode = "ZoneRedundant"
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
    value = kubernetes_secret.postgres.metadata[0].name
  }
}
```

## Features

- **Zone Redundant HA**: Automatic failover across availability zones
- **Geo-Redundant Backups**: Cross-region backup replication
- **Private Endpoint**: Secure VNet integration
- **Azure AD Authentication**: Optional AAD integration
- **Point-in-Time Recovery**: Up to retention period

## Cost Estimate (Azure)

- GP_Standard_D2s_v3: ~$150/month
- Storage (32GB): ~$5/month
- Backup storage: ~$10/month
- **Total**: ~$165-180/month

## Production Checklist

- [ ] Zone-redundant HA enabled
- [ ] Geo-redundant backups enabled
- [ ] Private endpoint configured
- [ ] Azure Monitor alerts configured
- [ ] Backup retention ≥ 7 days
- [ ] SSL enforcement enabled
- [ ] Network security groups configured

## Documentation

- [Azure PostgreSQL Flexible Server](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/)
- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
