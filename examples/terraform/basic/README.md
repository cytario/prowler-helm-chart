# Basic Prowler Deployment with Terraform

This example demonstrates how to deploy Prowler using Terraform with the default configuration, including internal PostgreSQL and Valkey instances.

## Architecture

```
┌─────────────────────────────────────────┐
│         Kubernetes Cluster              │
│  ┌──────────────────────────────────┐   │
│  │  Prowler Namespace               │   │
│  │  ├─ UI (2 replicas)              │   │
│  │  ├─ API (2 replicas)             │   │
│  │  ├─ Worker (2 replicas)          │   │
│  │  ├─ Worker Beat (1 replica)      │   │
│  │  ├─ PostgreSQL (StatefulSet)     │   │
│  │  └─ Valkey (Deployment)          │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Prerequisites

- Terraform >= 1.0
- kubectl configured with access to your Kubernetes cluster
- Sufficient cluster resources:
  - 4 CPU cores minimum
  - 8 GB RAM minimum
  - Storage class available (for persistent volumes)

## Usage

### 1. Copy and Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your values:

```hcl
postgres_password = "your-secure-password-here"
chart_path        = "../../../charts/prowler"  # Path to local chart
namespace         = "prowler"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan
```

Review the resources that will be created:
- Kubernetes namespace
- Helm release with all Prowler components

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Access the Application

After deployment completes, use the output commands:

```bash
# Access UI
terraform output -raw ui_access_command | bash

# In another terminal, access API
terraform output -raw api_access_command | bash
```

Then open:
- UI: http://localhost:3000
- API Docs: http://localhost:8080/api/v1/docs

## Configuration Options

### Scaling

Adjust replica counts in `terraform.tfvars`:

```hcl
api_replicas    = 3  # Scale API to 3 replicas
ui_replicas     = 2
worker_replicas = 4  # Scale workers to 4 replicas
```

### Storage

Control persistent storage:

```hcl
enable_persistence = true
storage_class      = "gp2"  # AWS EBS
# storage_class    = "standard"  # GKE Standard
# storage_class    = "managed-premium"  # AKS Premium
```

Disable persistence for testing:

```hcl
enable_persistence = false
```

### Kubernetes Context

Use a specific kubeconfig context:

```hcl
kubeconfig_path = "~/.kube/config"
kube_context    = "my-cluster-context"
```

## Monitoring

Check deployment status:

```bash
# View all resources
kubectl get all -n prowler

# Check pod status
kubectl get pods -n prowler

# View API logs
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api --tail=50
```

## Updating

To update the deployment with new values:

1. Modify `terraform.tfvars`
2. Run `terraform plan` to see changes
3. Run `terraform apply` to apply changes

## Cleanup

To remove all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

**Note**: Persistent volumes may need manual deletion:

```bash
kubectl delete pvc -n prowler --all
```

## Troubleshooting

### Pods Stuck in Pending

Check if storage class is available:

```bash
kubectl get storageclass
```

If no storage class exists, disable persistence:

```hcl
enable_persistence = false
```

### Helm Release Failed

View Helm status:

```bash
helm status prowler -n prowler
```

Check pod logs:

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api
```

### Database Connection Issues

Verify PostgreSQL is running:

```bash
kubectl get pods -n prowler -l app.kubernetes.io/name=postgresql
```

Check PostgreSQL logs:

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=postgresql
```

## Next Steps

- Configure cloud provider credentials in the UI
- Run your first security scan
- Set up external database (see `../external-postgresql/`)
- Configure ingress for external access
- Set up monitoring and alerting

## Support

For issues and questions:
- GitHub Issues: https://github.com/prowler-cloud/prowler-helm-chart/issues
- Documentation: https://docs.prowler.com
