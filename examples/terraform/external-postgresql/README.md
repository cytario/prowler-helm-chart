# Prowler with External PostgreSQL using Terraform

This example demonstrates how to deploy Prowler with an externally managed PostgreSQL database using Terraform. The PostgreSQL instance is deployed separately in the same namespace, allowing for independent scaling, backup, and management.

## Architecture

```
┌──────────────────────────────────────────────────┐
│         Kubernetes Cluster (prowler namespace)   │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  PostgreSQL (Separate Helm Release)        │  │
│  │  ├─ StatefulSet                            │  │
│  │  ├─ PVC (if persistence enabled)           │  │
│  │  └─ Service: prowler-postgres-postgresql   │  │
│  └────────────────┬───────────────────────────┘  │
│                   │ 5432                         │
│                   │                              │
│  ┌────────────────▼───────────────────────────┐  │
│  │  Prowler Application                       │  │
│  │  ├─ UI (2 replicas)                        │  │
│  │  ├─ API (2 replicas)          ────────┐    │  │
│  │  ├─ Worker (2 replicas)       ────────┤    │  │
│  │  ├─ Worker Beat (1 replica)   ────────┼─┐  │  │
│  │  │                                    │ │  │  │
│  │  │  [External DB Secret]              │ │  │  │
│  │  │   - POSTGRES_HOST ◄────────────────┘ │  │  │
│  │  │   - POSTGRES_USER                    │  │  │
│  │  │   - POSTGRES_PASSWORD                │  │  │
│  │  │   - POSTGRES_DB                      │  │  │
│  │  └──────────────────────────────────────┘  │  │
│  │                                            │  │
│  │  Valkey (Standalone)                       │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

## Benefits of External PostgreSQL

1. **Independent Scaling**: Scale database independently from application
2. **Easier Backups**: Manage database backups separately
3. **Version Control**: Update PostgreSQL version independently
4. **Resource Isolation**: Dedicated resources for database
5. **Better Monitoring**: Separate monitoring and alerting for database
6. **Testing**: Use different PostgreSQL configurations without affecting Prowler

## Prerequisites

- Terraform >= 1.0
- kubectl configured with access to your Kubernetes cluster
- Sufficient cluster resources:
  - 6 CPU cores minimum (database + application)
  - 12 GB RAM minimum
  - Storage class available (for PostgreSQL persistent volumes)

## Usage

### 1. Copy and Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set secure passwords:

```hcl
# PostgreSQL passwords (CHANGE THESE!)
postgres_admin_password = "your-very-secure-admin-password"
postgres_app_password   = "your-very-secure-app-password"

# Chart configuration
chart_path = "../../../charts/prowler"
namespace  = "prowler"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan
```

Review the resources:
- Kubernetes namespace
- PostgreSQL Helm release (separate)
- Kubernetes secret with database credentials
- Prowler Helm release (with `postgresql.enabled=false`)

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted. This will:
1. Create the namespace
2. Deploy PostgreSQL first
3. Create a secret with database connection details
4. Deploy Prowler configured to use external PostgreSQL

Deployment takes approximately 5-10 minutes.

### 5. Verify Deployment

Check all pods are running:

```bash
kubectl get pods -n prowler
```

Expected output:
```
NAME                                   READY   STATUS    RESTARTS   AGE
prowler-api-xxx                        1/1     Running   0          2m
prowler-api-yyy                        1/1     Running   0          2m
prowler-postgres-postgresql-0          1/1     Running   0          3m
prowler-ui-xxx                         1/1     Running   0          2m
prowler-ui-yyy                         1/1     Running   0          2m
prowler-valkey-xxx                     1/1     Running   0          2m
prowler-worker-xxx                     1/1     Running   0          2m
prowler-worker-yyy                     1/1     Running   0          2m
prowler-worker-beat-xxx                1/1     Running   0          2m
```

### 6. Verify Database Connection

Check API logs to confirm database connection:

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api --tail=50 | grep -i postgres
```

Check database tables were created:

```bash
# Get the admin password from Terraform output
POSTGRES_PASSWORD=$(terraform output -raw postgres_admin_password 2>/dev/null || echo "your-password")

# Connect to PostgreSQL and count tables
kubectl exec -n prowler prowler-postgres-postgresql-0 -- \
  env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U postgres -d prowler_db \
  -c "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';"
```

Expected output: ~63 tables created by Prowler migrations.

### 7. Access the Application

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

### Database Configuration

Customize PostgreSQL settings:

```hcl
postgres_version        = "18.1.4"  # PostgreSQL chart version
postgres_database       = "prowler_db"
postgres_username       = "prowler"
enable_postgres_persistence = true
```

### Scaling

Scale components independently:

```hcl
api_replicas    = 3  # Scale API
worker_replicas = 4  # Scale workers for more scan capacity
ui_replicas     = 2  # Scale UI
```

### Storage

Configure storage for PostgreSQL:

```hcl
enable_postgres_persistence = true
storage_class               = "gp2"  # AWS
# storage_class             = "standard"  # GKE
# storage_class             = "managed-premium"  # AKS
```

Disable Valkey persistence (recommended for ephemeral cache):

```hcl
enable_valkey_persistence = false
```

## Database Management

### Backup PostgreSQL

```bash
# Port-forward to PostgreSQL
kubectl port-forward -n prowler svc/prowler-postgres-postgresql 5432:5432 &

# Create backup
pg_dump -h localhost -U prowler prowler_db > prowler_backup_$(date +%Y%m%d).sql
```

### Restore PostgreSQL

```bash
# Port-forward to PostgreSQL
kubectl port-forward -n prowler svc/prowler-postgres-postgresql 5432:5432 &

# Restore backup
psql -h localhost -U prowler prowler_db < prowler_backup_20250118.sql
```

### Connect to PostgreSQL

```bash
# Get the password
POSTGRES_PASSWORD=$(terraform output -raw postgres_app_password)

# Connect via kubectl exec
kubectl exec -it -n prowler prowler-postgres-postgresql-0 -- \
  env PGPASSWORD="$POSTGRES_PASSWORD" \
  psql -U prowler -d prowler_db
```

Or via port-forward:

```bash
terraform output -raw postgres_access_command | bash
# Then: psql -h localhost -U prowler prowler_db
```

## Monitoring

### Check PostgreSQL Status

```bash
kubectl get pods -n prowler -l app.kubernetes.io/name=postgresql
kubectl logs -n prowler -l app.kubernetes.io/name=postgresql --tail=50
```

### Check Prowler API Database Connectivity

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api --tail=50
```

### View PostgreSQL Metrics

```bash
kubectl exec -n prowler prowler-postgres-postgresql-0 -- \
  env PGPASSWORD="$(terraform output -raw postgres_admin_password)" \
  psql -U postgres -d prowler_db \
  -c "SELECT datname, numbackends, xact_commit, xact_rollback FROM pg_stat_database WHERE datname='prowler_db';"
```

## Updating

### Update Prowler Only

To update Prowler without touching PostgreSQL:

```hcl
# In terraform.tfvars, change:
api_replicas = 3  # Scale API
```

Then:
```bash
terraform apply -target=helm_release.prowler
```

### Update PostgreSQL Only

```hcl
# In terraform.tfvars, change:
postgres_version = "18.1.5"  # New version
```

Then:
```bash
terraform apply -target=helm_release.postgresql
```

**⚠️ Warning**: PostgreSQL upgrades may require manual intervention. Always backup first!

### Update Both

```bash
terraform apply
```

## Migration from Internal to External PostgreSQL

If you have an existing Prowler deployment with internal PostgreSQL, you can migrate:

1. **Backup existing database**:
   ```bash
   kubectl exec -n prowler prowler-postgresql-0 -- \
     pg_dump -U prowler prowler_db > existing_backup.sql
   ```

2. **Deploy this example** (creates new external PostgreSQL)

3. **Restore data**:
   ```bash
   kubectl port-forward -n prowler svc/prowler-postgres-postgresql 5432:5432 &
   psql -h localhost -U prowler prowler_db < existing_backup.sql
   ```

4. **Delete old deployment**:
   ```bash
   helm uninstall old-prowler -n prowler
   kubectl delete pvc -n prowler -l app.kubernetes.io/name=postgresql
   ```

## Cleanup

### Remove Everything

```bash
terraform destroy
```

Type `yes` when prompted. This removes:
- Prowler Helm release
- PostgreSQL Helm release
- Kubernetes secret
- Namespace (if created by Terraform)

### Remove Persistent Volumes

PVCs may need manual deletion:

```bash
kubectl delete pvc -n prowler --all
```

To keep the data for future use, don't delete PVCs.

## Troubleshooting

### Prowler Pods Can't Connect to PostgreSQL

Check if PostgreSQL service is accessible:

```bash
kubectl get svc -n prowler prowler-postgres-postgresql
```

Check if secret is created:

```bash
kubectl get secret -n prowler prowler-postgres-secret
kubectl describe secret -n prowler prowler-postgres-secret
```

Verify environment variables in API pod:

```bash
kubectl exec -n prowler <api-pod-name> -- env | grep POSTGRES
```

### PostgreSQL Pod Not Starting

Check PostgreSQL logs:

```bash
kubectl logs -n prowler prowler-postgres-postgresql-0
```

Check PVC status:

```bash
kubectl get pvc -n prowler
```

### Database Migrations Failed

Check API logs:

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api | grep migration
```

Manually run migrations:

```bash
kubectl exec -n prowler <api-pod-name> -- python manage.py migrate
```

### Connection Pool Exhausted

Scale PostgreSQL connections or API replicas:

```hcl
api_replicas = 1  # Reduce concurrent connections temporarily
```

Or increase PostgreSQL max connections (requires custom values).

## Security Best Practices

1. **Use Strong Passwords**: Generate secure passwords:
   ```bash
   openssl rand -base64 32
   ```

2. **Store Passwords Securely**: Use Terraform Cloud, AWS Secrets Manager, or HashiCorp Vault

3. **Rotate Passwords Regularly**: Update passwords and apply:
   ```bash
   terraform apply -var="postgres_admin_password=new-password"
   ```

4. **Network Policies**: Implement Kubernetes NetworkPolicies to restrict PostgreSQL access

5. **Backup Encryption**: Encrypt database backups at rest

## Next Steps

- Configure automated backups (Velero, native PostgreSQL backups)
- Set up monitoring (Prometheus PostgreSQL Exporter)
- Implement connection pooling (PgBouncer)
- Configure read replicas for scaling reads
- Set up external managed PostgreSQL (see AWS RDS, Azure, GCP examples)

## Support

For issues and questions:
- GitHub Issues: https://github.com/prowler-cloud/prowler-helm-chart/issues
- Documentation: https://docs.prowler.com
