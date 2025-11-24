# Prowler Helm Chart - Terraform Deployment Examples

This directory contains comprehensive Terraform examples for deploying Prowler using Infrastructure as Code (IaC). Choose the deployment pattern that best fits your requirements.

## 📁 Available Examples

| Example | Description | Use Case | Difficulty |
|---------|-------------|----------|------------|
| [**basic/**](./basic/) | Basic deployment with internal PostgreSQL and Valkey | Development, testing, proof-of-concept | ⭐ Beginner |
| [**external-postgresql/**](./external-postgresql/) | Separate PostgreSQL deployment in same cluster | Better resource management, independent scaling | ⭐⭐ Intermediate |
| [**aws-rds/**](./aws-rds/) | AWS RDS PostgreSQL with EKS | Production AWS deployments, enterprise-grade reliability | ⭐⭐⭐ Advanced |
| [**azure-postgresql/**](./azure-postgresql/) | Azure Database for PostgreSQL with AKS | Production Azure deployments | ⭐⭐⭐ Advanced |
| [**gcp-cloudsql/**](./gcp-cloudsql/) | GCP Cloud SQL with GKE | Production GCP deployments | ⭐⭐⭐ Advanced |

## 🚀 Quick Start

### 1. Choose Your Deployment Pattern

**Starting out or testing?**
→ Use [`basic/`](./basic/) - simplest setup with all components included

**Need better resource isolation?**
→ Use [`external-postgresql/`](./external-postgresql/) - separate database management

**Running in production on AWS?**
→ Use [`aws-rds/`](./aws-rds/) - managed RDS with enterprise features

**Running in production on Azure?**
→ Use [`azure-postgresql/`](./azure-postgresql/) - Azure Database for PostgreSQL

**Running in production on GCP?**
→ Use [`gcp-cloudsql/`](./gcp-cloudsql/) - Cloud SQL with advanced features

### 2. Navigate to Example Directory

```bash
cd examples/terraform/<example-name>/
```

### 3. Follow Example-Specific README

Each example contains:
- `README.md` - Detailed instructions and architecture
- `versions.tf` - Provider configuration
- `variables.tf` - Configurable parameters
- `main.tf` - Resource definitions
- `outputs.tf` - Deployment outputs
- `terraform.tfvars.example` - Configuration template

### 4. Basic Workflow

```bash
# 1. Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# 2. Edit configuration with your values
nano terraform.tfvars

# 3. Initialize Terraform
terraform init

# 4. Preview changes
terraform plan

# 5. Apply configuration
terraform apply

# 6. Access outputs
terraform output
```

## 📊 Comparison Matrix

### Database Options

| Feature | Basic (Internal) | External PostgreSQL | AWS RDS | Azure PostgreSQL | GCP Cloud SQL |
|---------|-----------------|---------------------|---------|------------------|---------------|
| **Deployment** | In-cluster | In-cluster (separate) | AWS Managed | Azure Managed | GCP Managed |
| **High Availability** | Manual | Manual | Multi-AZ | Zone Redundant | Regional |
| **Automated Backups** | Manual | Manual | ✅ Yes | ✅ Yes | ✅ Yes |
| **Point-in-Time Recovery** | ❌ No | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Managed Patching** | ❌ No | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Performance Insights** | ❌ No | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Cost** | Lowest | Low | Medium | Medium | Medium |
| **Complexity** | Lowest | Low | High | High | High |
| **Best For** | Dev/Test | Staging | Production | Production | Production |

### Architecture Patterns

#### Pattern 1: All-in-One (Basic)
```
┌──────────────────────────────┐
│     Kubernetes Cluster       │
│  ┌────────────────────────┐  │
│  │ Prowler + PostgreSQL   │  │
│  │      + Valkey          │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```
**Pros**: Simple, quick setup, low cost
**Cons**: Resource contention, limited scalability

#### Pattern 2: Separated Database (External PostgreSQL)
```
┌──────────────────────────────┐
│     Kubernetes Cluster       │
│  ┌──────────┐  ┌──────────┐  │
│  │ Prowler  │→ │PostgreSQL│  │
│  │+ Valkey  │  │(Separate)│  │
│  └──────────┘  └──────────┘  │
└──────────────────────────────┘
```
**Pros**: Better isolation, independent scaling
**Cons**: More complex, still manual management

#### Pattern 3: Managed Database (AWS/Azure/GCP)
```
┌──────────────────────┐
│  Kubernetes Cluster  │
│  ┌────────────────┐  │
│  │    Prowler     │  │
│  │   + Valkey     │  │
│  └────────┬───────┘  │
└───────────┼──────────┘
            │
            ▼
┌───────────────────────┐
│  Managed PostgreSQL   │
│  (RDS/Azure/CloudSQL) │
└───────────────────────┘
```
**Pros**: Fully managed, enterprise features, HA
**Cons**: Higher cost, cloud-specific

## 🎯 Use Case Guide

### Development & Testing
```bash
cd examples/terraform/basic/
terraform apply
```
- Fast setup
- Minimal cost
- Easy cleanup

### Staging Environment
```bash
cd examples/terraform/external-postgresql/
terraform apply
```
- Production-like architecture
- Better resource management
- Independent database lifecycle

### Production - AWS
```bash
cd examples/terraform/aws-rds/
terraform apply
```
- Multi-AZ deployment
- Automated backups
- Performance Insights
- Enhanced monitoring

### Production - Azure
```bash
cd examples/terraform/azure-postgresql/
terraform apply
```
- Zone-redundant HA
- Geo-redundant backups
- Azure AD authentication
- Private endpoints

### Production - GCP
```bash
cd examples/terraform/gcp-cloudsql/
terraform apply
```
- Regional HA
- Point-in-time recovery
- Private IP connectivity
- Query Insights

## 🛠️ Prerequisites

### All Examples
- Terraform >= 1.0
- kubectl configured and working
- Access to Kubernetes cluster

### Cloud-Specific

**AWS (aws-rds/)**
- AWS CLI configured
- Existing EKS cluster
- VPC with private subnets
- Sufficient IAM permissions

**Azure (azure-postgresql/)**
- Azure CLI configured
- Existing AKS cluster
- Virtual Network configured
- Sufficient Azure RBAC permissions

**GCP (gcp-cloudsql/)**
- gcloud CLI configured
- Existing GKE cluster
- VPC network configured
- Sufficient IAM permissions

## 📋 Common Configuration Options

### Scaling Application Components

All examples support scaling:

```hcl
# terraform.tfvars
api_replicas    = 3  # Scale API for more throughput
ui_replicas     = 2  # Scale UI for more users
worker_replicas = 5  # Scale workers for more scan capacity
```

### Storage Configuration

```hcl
# Basic / External PostgreSQL
enable_persistence = true
storage_class     = "gp2"  # AWS EBS

# Cloud providers
rds_allocated_storage     = 500  # AWS RDS
rds_max_allocated_storage = 2000  # Autoscaling limit
```

### High Availability

```hcl
# AWS RDS
rds_multi_az = true  # Multi-AZ deployment

# Azure PostgreSQL
high_availability {
  mode = "ZoneRedundant"
}

# GCP Cloud SQL
availability_type = "REGIONAL"
```

## 🔒 Security Best Practices

### 1. Secrets Management

**Don't commit secrets to Git:**
```bash
echo "*.tfvars" >> .gitignore
echo "terraform.tfstate*" >> .gitignore
```

**Use Terraform Cloud or backend encryption:**
```hcl
terraform {
  backend "s3" {
    bucket  = "my-terraform-state"
    key     = "prowler/terraform.tfstate"
    encrypt = true
  }
}
```

**Use cloud secret managers:**
```hcl
# AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prowler/db-password"
}
```

### 2. Network Security

- Use private subnets for databases
- Implement security groups / NSGs / firewall rules
- Enable VPC flow logs
- Disable public accessibility for databases

### 3. Database Security

- Enable encryption at rest
- Enforce SSL/TLS connections
- Use IAM/AAD authentication where possible
- Implement least privilege access
- Enable audit logging

### 4. Kubernetes Security

- Use NetworkPolicies to restrict pod communication
- Enable Pod Security Standards
- Use separate service accounts with RBAC
- Scan container images for vulnerabilities

## 📈 Monitoring and Observability

### Application Monitoring

```bash
# Check pod health
kubectl get pods -n prowler

# View API logs
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api --tail=50 -f

# Check resource usage
kubectl top pods -n prowler
```

### Database Monitoring

**AWS RDS:**
- CloudWatch Metrics
- Performance Insights
- Enhanced Monitoring

**Azure PostgreSQL:**
- Azure Monitor
- Query Performance Insight
- Resource Health

**GCP Cloud SQL:**
- Cloud Monitoring
- Query Insights
- Operations logging

## 🔄 Migration Paths

### From Basic to External PostgreSQL

1. Backup existing database
2. Deploy external PostgreSQL example
3. Restore data to new database
4. Update Prowler configuration
5. Verify and switch over

### From External to Managed (RDS/Azure/GCP)

1. Backup existing database
2. Deploy managed database example
3. Restore backup to managed database
4. Update Prowler configuration
5. Verify and decommission old database

See individual example READMEs for detailed migration steps.

## 💰 Cost Optimization

### Development
- Use smallest instance types
- Disable Multi-AZ / HA
- Reduce backup retention
- Delete when not in use

### Production
- Right-size instances based on usage
- Use reserved instances / committed use discounts (30-60% savings)
- Enable storage autoscaling
- Implement lifecycle policies for backups

### Cost Examples (Monthly)

| Deployment | Environment | Estimated Cost |
|------------|-------------|----------------|
| Basic | Dev | $20-50 |
| External PostgreSQL | Staging | $50-100 |
| AWS RDS (t3.medium, Multi-AZ) | Production | $175-200 |
| AWS RDS (r6g.xlarge, Multi-AZ) | Production | $600-700 |
| Azure PostgreSQL (D2s_v3, HA) | Production | $165-180 |
| GCP Cloud SQL (custom-2-8, HA) | Production | $225-250 |

*Costs are approximate and vary by region, usage, and specific configuration.*

## 🧪 Testing Your Deployment

### 1. Verify All Pods Running

```bash
kubectl get pods -n prowler
```

Expected: All pods in `Running` state with `1/1` or `2/2` ready.

### 2. Check Database Connection

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api --tail=50 | grep -i "migration\|ready"
```

Expected: "Gunicorn server is ready" and successful migrations.

### 3. Access UI

```bash
kubectl port-forward -n prowler svc/prowler-ui 3000:3000
```

Visit: http://localhost:3000

### 4. Access API

```bash
kubectl port-forward -n prowler svc/prowler-api 8080:8080
```

Visit: http://localhost:8080/api/v1/docs

### 5. Run a Test Scan

1. Create user account in UI
2. Configure cloud provider credentials
3. Run a scan
4. Verify results appear

## 🆘 Troubleshooting

### Common Issues

**Issue: Pods stuck in Pending**
```bash
kubectl describe pod -n prowler <pod-name>
```
Solution: Check resource quotas, storage class, node capacity

**Issue: Database connection failed**
```bash
kubectl exec -n prowler <api-pod> -- env | grep POSTGRES
```
Solution: Verify credentials, security groups, network connectivity

**Issue: Terraform apply fails**
```bash
terraform apply -refresh-only
terraform plan
```
Solution: Check state file, verify permissions, review error messages

### Getting Help

1. Check example-specific README
2. Review Terraform error messages
3. Check pod/service logs
4. Consult cloud provider documentation
5. Open GitHub issue with:
   - Example being used
   - Terraform version
   - Error messages
   - Relevant logs

## 🔄 Updating

### Update Prowler Chart Version

```hcl
# terraform.tfvars
chart_version = "0.2.0"  # New version
```

```bash
terraform apply
```

### Update Database Version

Cloud providers handle minor version updates automatically. For major versions:

```hcl
# AWS RDS
rds_engine_version = "17.0"  # New major version
```

```bash
terraform apply
```

**⚠️ Warning**: Major version upgrades may require downtime. Test in non-production first.

## 📚 Additional Resources

### Terraform
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform Cloud](https://cloud.hashicorp.com/products/terraform)

### Kubernetes
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

### Cloud Providers
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Azure AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [GCP GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)

### Prowler
- [Prowler Documentation](https://docs.prowler.com)
- [Prowler GitHub](https://github.com/prowler-cloud/prowler)
- [Helm Chart Repository](https://github.com/prowler-cloud/prowler-helm-chart)

## 🤝 Contributing

Found an issue or have an improvement?

1. Open an issue describing the problem/enhancement
2. Submit a PR with your changes
3. Ensure all examples are tested
4. Update relevant documentation

## 📄 License

This project is licensed under the same license as the Prowler Helm Chart.

## 💬 Support

- **GitHub Issues**: [prowler-helm-chart/issues](https://github.com/prowler-cloud/prowler-helm-chart/issues)
- **Discussions**: [prowler-helm-chart/discussions](https://github.com/prowler-cloud/prowler-helm-chart/discussions)
- **Documentation**: [docs.prowler.com](https://docs.prowler.com)

---

**Next Steps:**
1. Choose your deployment pattern
2. Navigate to the example directory
3. Follow the example-specific README
4. Deploy Prowler with Terraform! 🚀
