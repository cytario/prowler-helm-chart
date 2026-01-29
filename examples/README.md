# Prowler Helm Chart - Configuration Examples

This directory contains example values files for common deployment scenarios. These examples demonstrate best practices and production-ready configurations.

## Available Examples

### 📋 values-production.yaml
**Complete production-ready configuration**

Demonstrates a full production deployment with:
- External managed databases (PostgreSQL and Valkey)
- Resource limits for all components
- Persistent storage for scan outputs
- Ingress with TLS termination
- Network policies enabled
- High availability with multiple replicas
- Pod Disruption Budgets
- Horizontal Pod Autoscaling
- Security contexts and best practices

**Use this when:**
- Deploying to production environments
- You need high availability and scalability
- You want a comprehensive reference for all configuration options

**Usage:**
```bash
# 1. Create external database secrets first
kubectl create namespace prowler
kubectl create secret generic prowler-postgres-secret -n prowler \
  --from-literal=POSTGRES_HOST=your-db-endpoint \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_ADMIN_USER=prowler_admin \
  --from-literal=POSTGRES_ADMIN_PASSWORD=your-admin-password \
  --from-literal=POSTGRES_USER=prowler \
  --from-literal=POSTGRES_PASSWORD=your-user-password \
  --from-literal=POSTGRES_DB=prowler_db

kubectl create secret generic prowler-valkey-secret -n prowler \
  --from-literal=VALKEY_HOST=your-cache-endpoint \
  --from-literal=VALKEY_PORT=6379 \
  --from-literal=VALKEY_PASSWORD=your-valkey-password \
  --from-literal=VALKEY_DB=0

# 2. Update hostnames in the file
vi examples/values-production.yaml
# Change prowler.example.com to your domain

# 3. Install with production values
helm install prowler charts/prowler \
  -f examples/values-production.yaml \
  --set neo4j.auth.password=YOUR_NEO4J_PASSWORD \
  -n prowler
```

---

### 🗄️ values-external-db.yaml
**External database configuration guide**

Focused example showing how to connect Prowler to external managed databases (AWS RDS, Azure Database, Google Cloud SQL, etc.).

Includes:
- Detailed setup instructions for external PostgreSQL and Valkey/Redis
- Cloud provider specific examples (AWS, Azure, GCP)
- Network configuration guidance
- Performance tuning recommendations
- Backup and disaster recovery strategies
- Migration guide from built-in to external databases
- Troubleshooting common connection issues

**Use this when:**
- Migrating from built-in databases to managed services
- Setting up external databases for the first time
- You need reference for cloud-specific configurations
- Troubleshooting database connectivity issues

**Usage:**
```bash
# Follow the detailed instructions in the file comments
helm install prowler charts/prowler \
  -f examples/values-external-db.yaml \
  -n prowler
```

---

### ☁️ values-aws.yaml
**Amazon Web Services (AWS) EKS deployment**

Complete AWS EKS deployment configuration with:
- IAM Roles for Service Accounts (IRSA) for secure AWS credentials
- AWS Load Balancer Controller for ingress
- Amazon RDS for PostgreSQL
- Amazon ElastiCache for Redis
- EBS/EFS CSI driver for persistent storage
- VPC networking integration
- CloudWatch monitoring
- Detailed setup instructions for all AWS services

**Use this when:**
- Deploying on Amazon EKS
- Need AWS-specific integrations (RDS, ElastiCache, ALB)
- Want to use IRSA for secure credential management
- Setting up production AWS deployment

**Usage:**
```bash
# See detailed prerequisites and setup instructions in the file
helm install prowler charts/prowler \
  -f examples/values-aws.yaml \
  -n prowler
```

---

### ☁️ values-azure.yaml
**Microsoft Azure AKS deployment**

Complete Azure AKS deployment configuration with:
- Azure Workload Identity for secure Azure credentials
- Application Gateway Ingress Controller
- Azure Database for PostgreSQL
- Azure Cache for Redis
- Azure Disk/Files storage
- Azure Monitor integration
- VNet integration
- Detailed setup instructions for all Azure services

**Use this when:**
- Deploying on Azure Kubernetes Service (AKS)
- Need Azure-specific integrations (Azure Database, Azure Cache, Application Gateway)
- Want to use Workload Identity for secure credential management
- Setting up production Azure deployment

**Usage:**
```bash
# See detailed prerequisites and setup instructions in the file
helm install prowler charts/prowler \
  -f examples/values-azure.yaml \
  -n prowler
```

---

### ☁️ values-gcp.yaml
**Google Cloud Platform (GCP) GKE deployment**

Complete GCP GKE deployment configuration with:
- Workload Identity for secure GCP credentials
- GCE Ingress Controller with Cloud Load Balancer
- Cloud SQL for PostgreSQL with Cloud SQL Proxy
- Memorystore for Redis
- Persistent Disk/Filestore storage
- Cloud Monitoring integration
- VPC networking
- Detailed setup instructions for all GCP services

**Use this when:**
- Deploying on Google Kubernetes Engine (GKE)
- Need GCP-specific integrations (Cloud SQL, Memorystore, GCE Load Balancer)
- Want to use Workload Identity for secure credential management
- Setting up production GCP deployment

**Usage:**
```bash
# See detailed prerequisites and setup instructions in the file
helm install prowler charts/prowler \
  -f examples/values-gcp.yaml \
  -n prowler
```

---

## General Usage Tips

### 1. Start with Defaults
For development or testing, the default `values.yaml` works with Neo4j password:
```bash
helm install prowler charts/prowler -n prowler --create-namespace \
  --set neo4j.auth.password=your-password
```

### 2. Combine Multiple Files
You can combine multiple values files:
```bash
helm install prowler charts/prowler \
  -f examples/values-production.yaml \
  -f my-custom-overrides.yaml \
  -n prowler
```

Later files override earlier ones.

### 3. Override Individual Values
Use `--set` for quick overrides:
```bash
helm install prowler charts/prowler \
  -f examples/values-production.yaml \
  --set api.replicaCount=5 \
  --set worker.autoscaling.maxReplicas=30 \
  -n prowler
```

### 4. Preview Changes
Always preview before applying:
```bash
helm template prowler charts/prowler \
  -f examples/values-production.yaml \
  -n prowler
```

Or use `helm diff` plugin:
```bash
helm diff upgrade prowler charts/prowler \
  -f examples/values-production.yaml \
  -n prowler
```

### 5. Validate Configuration
Lint and validate before deploying:
```bash
# Helm lint
helm lint charts/prowler -f examples/values-production.yaml

# Chart testing
ct lint --config ct.yaml --charts charts/prowler

# Kubernetes validation
helm template prowler charts/prowler \
  -f examples/values-production.yaml | \
  kubeval --kubernetes-version 1.29.0 --strict
```

## Creating Your Own Values File

### Recommended Approach

1. **Start with an example:**
   ```bash
   cp examples/values-production.yaml my-values.yaml
   ```

2. **Customize for your environment:**
   - Update hostnames and domains
   - Adjust resource limits based on your workload
   - Configure cloud provider specific settings
   - Add your secret references
   - Modify replica counts

3. **Store in version control:**
   ```bash
   git add my-values.yaml
   git commit -m "Add custom Prowler configuration"
   ```

4. **Use environment-specific files:**
   ```
   values-dev.yaml
   values-staging.yaml
   values-production.yaml
   ```

### Common Customizations

#### Adjust Resource Limits
```yaml
api:
  resources:
    limits:
      cpu: 4000m      # Increase for high load
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 1Gi
```

#### Configure Autoscaling
```yaml
worker:
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 50
    targetCPUUtilizationPercentage: 60
```

#### Add Cloud Provider IAM Roles
```yaml
# AWS
worker:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prowler-scanner

# Azure
worker:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "12345678-1234-1234-1234-123456789012"

# GCP
worker:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: prowler@my-project.iam.gserviceaccount.com
```

#### Configure Ingress
```yaml
api:
  ingress:
    enabled: true
    className: "nginx"  # or "traefik", "alb", etc.
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: prowler-api.mycompany.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: prowler-api-tls
        hosts:
          - prowler-api.mycompany.com
```

## Best Practices

1. **Never commit secrets to version control**
   - Use Kubernetes secrets
   - Consider External Secrets Operator
   - Use sealed-secrets for GitOps

2. **Use persistent storage in production**
   ```yaml
   sharedStorage:
     type: persistentVolumeClaim
     persistentVolumeClaim:
       create: true
       size: 50Gi
   ```

3. **Enable resource limits**
   - Prevents resource exhaustion
   - Helps with scheduling and bin packing
   - Required for autoscaling

4. **Configure health checks**
   - startupProbe for slow-starting containers
   - livenessProbe for detecting deadlocks
   - readinessProbe for load balancer routing

5. **Enable Pod Disruption Budgets**
   ```yaml
   api:
     podDisruptionBudget:
       enabled: true
       minAvailable: 2
   ```

6. **Use anti-affinity for HA**
   - Spreads pods across nodes
   - Prevents single point of failure
   - See production example for configuration

## Need Help?

- **Documentation:** [../README.md](../README.md)
- **Contributing:** [../.github/CONTRIBUTING.md](../.github/CONTRIBUTING.md)
- **Issues:** [GitHub Issues](https://github.com/promptlylabs/prowler-helm-chart/issues)
- **Discussions:** [GitHub Discussions](https://github.com/promptlylabs/prowler-helm-chart/discussions)

## Additional Resources

- [Helm Values Files](https://helm.sh/docs/chart_template_guide/values_files/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Prowler Documentation](https://docs.prowler.com/)
