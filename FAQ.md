# Frequently Asked Questions (FAQ)

Common questions about deploying and using the Prowler Helm chart.

## Table of Contents

- [General Questions](#general-questions)
- [Installation & Setup](#installation--setup)
- [Configuration](#configuration)
- [Storage & Persistence](#storage--persistence)
- [Security](#security)
- [Scaling & Performance](#scaling--performance)
- [Cloud Provider Specific](#cloud-provider-specific)
- [Troubleshooting](#troubleshooting)
- [Neo4j (Attack Paths)](#neo4j-attack-paths)

---

## General Questions

### What is Prowler?

Prowler is an open-source security tool for AWS, Azure, GCP, and Kubernetes security assessment and compliance checking. It performs security best practice checks, generates compliance reports, and helps identify security risks in your cloud infrastructure.

The Prowler Helm chart deploys the Prowler web application, which provides:
- Web UI for managing scans and viewing results
- REST API for programmatic access
- Background workers for executing security scans
- Database for storing scan results and configurations

### What are the minimum requirements?

**Kubernetes:**
- Version 1.21 or higher
- At least 3 nodes (for high availability)
- 8 GB RAM total across cluster
- 4 CPU cores total across cluster

**For Development/Testing:**
- Single node: 4 GB RAM, 2 CPU cores
- Can use Minikube, kind, k3s, or MicroK8s

**For Production:**
- Multiple nodes for high availability
- External managed databases (PostgreSQL, Redis/Valkey)
- Persistent storage with ReadWriteMany support
- Ingress controller for external access

See [Installation Requirements](README.md#requirements) for details.

### Is this the official Prowler Helm chart?

This is a community-maintained Helm chart for deploying the Prowler web application. While it follows best practices and is actively maintained, for official support and enterprise features, please contact Prowler Cloud.

### What's the difference between Prowler CLI and this Helm chart?

**Prowler CLI:**
- Command-line tool for one-time scans
- Runs locally or in CI/CD pipelines
- Outputs results to files (JSON, CSV, HTML)
- No database or web interface

**Prowler Helm Chart (Web Application):**
- Deploys web UI and API
- Continuous scanning with scheduling
- Stores results in database
- Multi-user access with authentication
- Historical trend analysis
- Team collaboration features

Both use the same Prowler scanning engine under the hood.

---

## Installation & Setup

### Do I need to configure databases before installing?

**Short answer:** No, not for basic installation.

**Details:**

The chart includes PostgreSQL and Valkey (Redis) as dependencies. For a quick start:

```bash
helm install prowler charts/prowler -n prowler --create-namespace
```

The built-in databases work fine for:
- Development
- Testing
- Small deployments
- Single-cluster setups

**For production, we recommend external managed databases:**
- Better reliability and backup
- Automatic failover
- Better performance
- Independent scaling

See [examples/values-external-db.yaml](examples/values-external-db.yaml) for setup instructions.

### How do I access Prowler after installation?

**Method 1: Port Forward (Development)**
```bash
kubectl port-forward -n prowler svc/prowler-ui 3000:3000
```
Then visit http://localhost:3000

**Method 2: Ingress (Production)**

Enable ingress in your values:
```yaml
ui:
  ingress:
    enabled: true
    hosts:
      - host: prowler.example.com
```

Then visit https://prowler.example.com

### What are the default credentials?

There are no default credentials. You must create a superuser after installation:

```bash
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py createsuperuser
```

Follow the prompts to create username, email, and password.

### Can I use an existing PostgreSQL database?

Yes! This chart requires external PostgreSQL and Valkey/Redis instances. Create secrets with your credentials:

```bash
kubectl create secret generic prowler-postgres-secret -n prowler \
  --from-literal=POSTGRES_HOST=your-db-host \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_ADMIN_USER=prowler_admin \
  --from-literal=POSTGRES_ADMIN_PASSWORD=your-admin-password \
  --from-literal=POSTGRES_USER=prowler \
  --from-literal=POSTGRES_PASSWORD=your-user-password \
  --from-literal=POSTGRES_DB=prowler_db

kubectl create secret generic prowler-valkey-secret -n prowler \
  --from-literal=VALKEY_HOST=your-redis-host \
  --from-literal=VALKEY_PORT=6379 \
  --from-literal=VALKEY_PASSWORD=your-password \
  --from-literal=VALKEY_DB=0
```

Then install with:
```bash
helm install prowler charts/prowler -n prowler
```

See [examples/values-external-db.yaml](examples/values-external-db.yaml) for complete configuration.

---

## Configuration

### How do I customize resource limits?

Edit your values file or use `--set`:

```yaml
api:
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

Or with `--set`:
```bash
helm upgrade prowler charts/prowler \
  --set api.resources.limits.cpu=2000m \
  --set api.resources.limits.memory=2Gi \
  -n prowler
```

The default values.yaml includes commented recommendations for each component. See [Resource Recommendations](charts/prowler/values.yaml).

### How do I enable autoscaling?

Enable Horizontal Pod Autoscaler for any component:

```yaml
api:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

Requirements:
- Metrics Server must be installed in your cluster
- Resource requests must be defined
- Recommended for API and Worker components

### How do I configure cloud credentials for scanning?

Cloud credentials should be provided via Kubernetes secrets or cloud provider IAM roles.

**AWS (Recommended: IAM Roles for Service Accounts)**
```yaml
worker:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/prowler-scanner
```

**Azure (Recommended: Workload Identity)**
```yaml
worker:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "12345678-1234-1234-1234-123456789012"
```

**GCP (Recommended: Workload Identity)**
```yaml
worker:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: prowler@project.iam.gserviceaccount.com
```

**Alternative: Kubernetes Secrets**
Create a secret with cloud credentials and reference it:
```yaml
worker:
  secrets:
    - prowler-aws-credentials
```

### Can I use my own SSL/TLS certificates?

Yes! You can use:

**1. Cert-Manager (Recommended)**
```yaml
ui:
  ingress:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: prowler-ui-tls
        hosts:
          - prowler.example.com
```

**2. Pre-existing Certificate**
```bash
kubectl create secret tls prowler-ui-tls -n prowler \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

Then reference in values:
```yaml
ui:
  ingress:
    enabled: true
    tls:
      - secretName: prowler-ui-tls
        hosts:
          - prowler.example.com
```

---

## Storage & Persistence

### What storage do I need?

Prowler requires two types of storage:

**1. Shared Storage (Required)**
- Stores scan output files
- Must be shared between API and Worker pods
- Requires ReadWriteMany (RWX) if using PVC

**2. Component Storage (Optional)**
- API config storage: Prowler CLI configuration
- Worker config storage: Cloud credentials and config

### Do I need ReadWriteMany storage?

**It depends on your configuration:**

**Yes, if:**
- Using PersistentVolumeClaim for shared storage
- Running multiple API or Worker replicas
- Want data persistence

**No, if:**
- Using emptyDir (data not persisted)
- Running single replica of API and Worker
- Using ReadWriteOnce with pod affinity

**Cloud provider RWX options:**
- **AWS:** EFS (via EFS CSI driver)
- **Azure:** Azure Files (Premium or Standard)
- **GCP:** Filestore
- **On-premises:** NFS, Ceph, GlusterFS

### Can I use emptyDir instead of PVC?

Yes, for development/testing:

```yaml
sharedStorage:
  type: emptyDir
```

**Pros:**
- Simple, no storage provisioning needed
- Fast (can use memory: `medium: Memory`)
- Works everywhere

**Cons:**
- Data lost when pods restart
- Not suitable for production
- Cannot share between nodes

### How much storage do I need?

**Minimum (Development):**
- Shared storage: 1 GB
- PostgreSQL: 8 GB
- Valkey: 1 GB

**Recommended (Production):**
- Shared storage: 50-100 GB (depends on scan frequency and retention)
- PostgreSQL: 100+ GB (database with backups)
- Valkey: 1-5 GB (task queue)

**Growth factors:**
- Number of cloud accounts scanned
- Scan frequency
- Data retention period
- Number of resources per account

---

## Security

### How secure is the default configuration?

The default configuration follows Kubernetes security best practices:

✅ **Included:**
- Pod Security Standards (restricted)
- Security contexts (non-root, dropped capabilities)
- ReadOnlyRootFilesystem where possible
- Seccomp profiles (RuntimeDefault)
- No hardcoded secrets
- Auto-generated encryption keys

⚠️ **You should add:**
- Strong PostgreSQL passwords
- TLS/SSL for ingress
- Network policies (available but disabled by default)
- External secrets management (e.g., External Secrets Operator)
- Regular security updates

### Should I use Network Policies?

**Yes, for production.** Network Policies provide defense-in-depth by restricting pod-to-pod communication.

Enable in values:
```yaml
networkPolicy:
  enabled: true
```

**Requirements:**
- CNI plugin with network policy support (Calico, Cilium, etc.)
- Not supported on: Basic kubenet (AKS), default GKE networks

**What it does:**
- Restricts ingress to UI/API from ingress controller only
- Allows egress to databases and cloud APIs
- Blocks unauthorized pod communication

### How are Django keys managed?

Django keys (JWT signing, encryption) are auto-generated by a pre-install Kubernetes Job:

1. Job runs before main installation
2. Generates secure RSA keys for JWT
3. Generates Fernet key for field encryption
4. Stores in Kubernetes Secret
5. Secret is mounted to API, Worker, Worker Beat pods

**Key generation is:**
- Automatic
- Secure (using Helm's `lookup` function for persistence)
- Unique per installation

**For existing secrets:** The chart uses Helm's `lookup` to detect existing secrets and reuses them across upgrades.

### Can I use external secret management?

Yes! You can integrate with:

**External Secrets Operator:**
```yaml
api:
  djangoConfigKeys:
    create: false  # Disable built-in secret generation
  secrets:
    - prowler-django-keys  # Reference external secret
```

**Sealed Secrets:**
```bash
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
kubectl apply -f sealed-secret.yaml
```

**Cloud Provider Secret Managers:**
- AWS Secrets Manager (via External Secrets)
- Azure Key Vault (via CSI driver or External Secrets)
- Google Secret Manager (via External Secrets)

### How do I rotate Django keys?

⚠️ **Warning:** Rotating JWT keys invalidates all active user sessions.

```bash
# 1. Delete existing secret
kubectl delete secret prowler-api-django-config-keys -n prowler

# 2. Delete generation job to trigger recreation
kubectl delete job prowler-generate-keys -n prowler

# 3. Upgrade Helm release (recreates job)
helm upgrade prowler charts/prowler -n prowler --reuse-values

# 4. Wait for job completion
kubectl wait --for=condition=complete job/prowler-generate-keys -n prowler

# 5. Restart pods to load new keys
kubectl rollout restart deployment -n prowler
```

All users will need to log in again.

---

## Scaling & Performance

### How many replicas should I run?

**Development:**
```yaml
api: 1
ui: 1
worker: 1
worker_beat: 1  # Always 1
```

**Small Production (< 10 cloud accounts):**
```yaml
api: 2-3
ui: 2-3
worker: 2-3
worker_beat: 1
```

**Medium Production (10-100 accounts):**
```yaml
api: 3-5
ui: 3-5
worker: 5-10
worker_beat: 1
```

**Large Production (100+ accounts):**
```yaml
api: 5-10 (with autoscaling)
ui: 5-10 (with autoscaling)
worker: 10-50 (with autoscaling)
worker_beat: 1
```

**Note:** Worker Beat should always be 1 (it's a scheduler, not a worker).

### How do I improve scan performance?

**1. Scale Workers Horizontally**
```yaml
worker:
  replicaCount: 10
  autoscaling:
    enabled: true
    maxReplicas: 50
```

**2. Increase Worker Resources**
```yaml
worker:
  resources:
    limits:
      cpu: 4000m
      memory: 4Gi
```

**3. Use Faster Storage**
- Use SSD-backed storage
- Consider memory-backed emptyDir for temporary scan data

**4. Optimize Database**
- Use external managed database
- Enable connection pooling (PgBouncer, RDS Proxy)
- Scale database instance

**5. Use Dedicated Worker Nodes**
```yaml
worker:
  nodeSelector:
    workload-type: prowler-worker
  tolerations:
    - key: "workload-type"
      value: "prowler-worker"
      effect: "NoSchedule"
```

### What are the performance bottlenecks?

**Common bottlenecks:**

1. **Database connections** - Solution: Use external database with connection pooling
2. **Worker concurrency** - Solution: Scale worker replicas
3. **Storage I/O** - Solution: Use faster storage or increase IOPS
4. **Cloud API rate limits** - Solution: Distribute scans across time
5. **Memory limits** - Solution: Increase worker memory limits

Monitor with:
```bash
kubectl top pods -n prowler
kubectl top nodes
```

---

## Cloud Provider Specific

### AWS - How do I set up IAM roles?

**Using IRSA (IAM Roles for Service Accounts):**

1. Create IAM role with Prowler permissions:
```bash
eksctl create iamserviceaccount \
  --name prowler-worker \
  --namespace prowler \
  --cluster your-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/SecurityAudit \
  --approve
```

2. Configure in values:
```yaml
worker:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/prowler-worker
```

### Azure - How do I set up Workload Identity?

**Using Azure Workload Identity:**

1. Create managed identity and assign permissions
2. Federate with Kubernetes service account
3. Configure in values:
```yaml
worker:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "your-client-id"
  podLabels:
    azure.workload.identity/use: "true"
```

### GCP - How do I set up Workload Identity?

**Using GCP Workload Identity:**

1. Create GCP service account with necessary roles
2. Bind to Kubernetes service account
3. Configure in values:
```yaml
worker:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: prowler@project.iam.gserviceaccount.com
```

### Which cloud providers support ReadWriteMany?

- ✅ **AWS:** EFS (via EFS CSI driver)
- ✅ **Azure:** Azure Files (Standard and Premium tiers)
- ✅ **GCP:** Filestore
- ❌ **AWS:** EBS (ReadWriteOnce only)
- ❌ **Azure:** Azure Disks (ReadWriteOnce only)
- ❌ **GCP:** Persistent Disk (ReadWriteOnce only)

For single-AZ deployments, you can use ReadWriteOnce with single replicas or pod affinity.

---

## Troubleshooting

### Pods are in CrashLoopBackOff

See detailed troubleshooting: [docs/troubleshooting.md#pod-startup-problems](docs/troubleshooting.md#pod-startup-problems)

Quick checks:
```bash
kubectl get pods -n prowler
kubectl logs -n prowler <pod-name>
kubectl describe pod -n prowler <pod-name>
```

Common causes:
- Database connection failure
- Invalid configuration
- Resource limits too low
- Missing secrets

### Login doesn't work

See: [docs/troubleshooting.md#authentication-and-login-problems](docs/troubleshooting.md#authentication-and-login-problems)

Common causes:
- No superuser created yet
- Invalid Django keys
- API not accessible from UI

### Scans are not running

See: [docs/troubleshooting.md#worker-and-celery-issues](docs/troubleshooting.md#worker-and-celery-issues)

Common causes:
- Workers not running
- Worker Beat not scheduling
- Cloud credentials not configured
- Database connection issues

### How do I enable debug logging?

```yaml
api:
  djangoConfig:
    DJANGO_DEBUG: "True"
    DJANGO_LOG_LEVEL: "DEBUG"
```

⚠️ **Warning:** Debug mode exposes sensitive information. Only use in development.

For production debugging:
```yaml
api:
  djangoConfig:
    DJANGO_LOG_LEVEL: "INFO"  # or "DEBUG" temporarily
```

Then check logs:
```bash
kubectl logs -n prowler -l app.kubernetes.io/component=api -f
```

---

## Neo4j (Attack Paths)

### What is Neo4j used for in Prowler?

Neo4j (DozerDB) is a graph database used by Prowler's **Attack Paths** feature (introduced in Prowler 5.17+). It stores relationships between cloud resources to identify potential attack paths and security risks.

### Is Neo4j required?

**Yes**, for Prowler 5.17+. Neo4j is enabled by default in this chart. If you disable it (`neo4j.enabled=false`), the Attack Paths feature will not work and API/Worker pods may crash.

### How do I set the Neo4j password?

Neo4j password is **auto-generated** if not provided. To set your own:

```bash
helm install prowler charts/prowler \
  --set neo4j.auth.password=your-secure-password \
  -n prowler
```

The auto-generated password is preserved across upgrades using Helm's `lookup` function.

### Can I use an external Neo4j instance?

Currently, the chart only supports the built-in Neo4j (DozerDB) deployment. External Neo4j support may be added in future versions.

### How do I enable Neo4j persistence?

Persistence is **enabled by default**. To explicitly configure it:

```yaml
neo4j:
  persistence:
    enabled: true
    size: 20Gi
    storageClass: "your-storage-class"
```

### How do I access Neo4j Browser for debugging?

```bash
kubectl port-forward -n prowler svc/prowler-neo4j 7474:7474 7687:7687
```

Then open http://localhost:7474 and login with:
- Username: `neo4j`
- Password: (the password you set during installation)

### How much memory does Neo4j need?

Default configuration:
- Requests: 2Gi memory, 500m CPU
- Limits: 4Gi memory, 2000m CPU
- Heap: 1G initial, 1G max
- Page cache: 1G

For large deployments (many cloud accounts), increase these values:

```yaml
neo4j:
  resources:
    limits:
      memory: 8Gi
  config:
    heapMaxSize: "4G"
    pagecacheSize: "2G"
```

---

## Additional Questions?

- **Troubleshooting Guide:** [docs/troubleshooting.md](docs/troubleshooting.md)
- **Upgrade Guide:** [UPGRADING.md](UPGRADING.md)
- **Contributing:** [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)
- **GitHub Issues:** [prowler-helm-chart/issues](https://github.com/cytario/prowler-helm-chart/issues)
- **GitHub Discussions:** [prowler-helm-chart/discussions](https://github.com/cytario/prowler-helm-chart/discussions)
- **Prowler Documentation:** [docs.prowler.com](https://docs.prowler.com/)
