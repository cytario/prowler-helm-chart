<!--
This README is the one shown on the Homepage of the repository
Images should use relative URLs.
-->

# Prowler Helm Chart

![Version: 0.0.2](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square)
![AppVersion: 5.5.1](https://img.shields.io/badge/AppVersion-1.1.0-informational?style=flat-square)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/prowler-app)](https://artifacthub.io/packages/helm/prowler-app/prowler)

**Deploy Prowler's web application on Kubernetes with this production-ready Helm chart.**

Prowler is an Open Cloud Security tool for AWS, Azure, GCP and Kubernetes. It helps with continuous monitoring, security assessments and audits, incident response, compliance, hardening and forensics readiness. Includes CIS, NIST 800, NIST CSF, CISA, FedRAMP, PCI-DSS, GDPR, HIPAA, FFIEC, SOC2, GXP, Well-Architected Security, ENS and more.

This chart deploys the [Prowler App](https://docs.prowler.com/projects/prowler-open-source/en/latest/#prowler-app) (web UI + API), not the [Prowler Dashboard](https://docs.prowler.com/projects/prowler-open-source/en/latest/#prowler-dashboard).

## ✨ Features

- **🚀 One-Command Deployment** - Get Prowler running in minutes with sensible defaults
- **🔒 Security by Default** - Pod Security Standards, non-root containers, auto-generated secrets
- **📊 Web UI & REST API** - User-friendly interface and programmatic access
- **🔄 Scheduled Scanning** - Automatic recurring security scans with Celery
- **📈 Horizontal Autoscaling** - Built-in HPA support for API and Workers
- **💾 Flexible Storage** - Support for emptyDir, PVC, and cloud provider storage
- **🗄️ Database Options** - Built-in PostgreSQL/Valkey or bring your own managed databases
- **🌐 Ingress Ready** - Built-in Ingress configuration with TLS support
- **🔐 RBAC & Network Policies** - Fine-grained access control and network segmentation
- **☁️ Cloud Native** - IAM roles for service accounts (AWS IRSA, Azure Workload Identity, GCP Workload Identity)
- **📦 Production Examples** - Ready-to-use configurations for production deployments
- **🔧 Highly Configurable** - Extensive customization options via values.yaml

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Architecture](#architecture)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Security](#-security)
- [Examples](#-examples)
- [Documentation](#-documentation)
- [Upgrading](#-upgrading)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

## 📦 Requirements

### Kubernetes Cluster

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **Kubernetes Version** | 1.21+ | 1.27+ | PodDisruptionBudget requires 1.21+ |
| **Helm Version** | 3.0+ | 3.12+ | Helm 3.8+ recommended for OCI support |
| **CPU** | 2 cores | 8+ cores | For development vs production |
| **Memory** | 4 GB | 16+ GB | For development vs production |
| **Nodes** | 1 | 3+ | For high availability |
| **Storage Class** | Any | RWX-capable | ReadWriteMany for shared storage |

### Optional Components

| Component | Purpose | Required For |
|-----------|---------|--------------|
| **Ingress Controller** | External access | Production deployments |
| **Cert-Manager** | TLS certificates | HTTPS with Let's Encrypt |
| **Metrics Server** | Autoscaling | HPA (Horizontal Pod Autoscaler) |
| **CNI with Network Policies** | Network segmentation | Network Policies feature |
| **External Databases** | Production reliability | Production deployments |

### Cloud Provider Storage Options

| Provider | ReadWriteOnce | ReadWriteMany | Notes |
|----------|---------------|----------------|-------|
| **AWS** | EBS ✅ | EFS ✅ | EFS requires CSI driver |
| **Azure** | Managed Disks ✅ | Azure Files ✅ | Both Standard and Premium |
| **GCP** | Persistent Disk ✅ | Filestore ✅ | Filestore for RWX |
| **On-premises** | Most storage ✅ | NFS, Ceph, GlusterFS ✅ | Depends on setup |

### Development/Testing

For local development or testing:
- **Minikube** (2 CPUs, 4 GB RAM minimum)
- **kind** (Docker Desktop with 4 GB RAM)
- **k3s** (Lightweight Kubernetes)
- **MicroK8s** (Ubuntu/Linux)

See [FAQ.md](FAQ.md#what-are-the-minimum-requirements) for detailed requirements.

## Architecture

The Prowler App consists of three main components:

- **Prowler UI**: A user-friendly web interface for running Prowler and viewing results, powered by Next.js.
- **Prowler API**: The backend API that executes Prowler scans and stores the results, built with Django REST Framework.
- **Prowler SDK**: A Python SDK that integrates with the Prowler CLI for advanced functionality.

The app leverages the following supporting infrastructure:

- **PostgreSQL**: Used for persistent storage of scan results.
- **Celery Workers**: Facilitate asynchronous execution of Prowler scans.
- **Valkey**: An in-memory database serving as a message broker for the Celery workers.
- **Neo4j (DozerDB)**: Graph database for Attack Paths feature (Prowler 5.17+).

![prowler architecture](docs/images/architecture.png)

## 🚀 Quick Start

Get Prowler running in 2 minutes:

```bash
# Add Helm repository
helm repo add prowler-app https://promptlylabs.github.io/prowler-helm-chart
helm repo update

# Install with default settings
helm install prowler prowler-app/prowler \
  --create-namespace \
  --namespace prowler

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=prowler -n prowler --timeout=5m

# Create superuser for login
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py createsuperuser

# Access UI (port-forward for testing)
kubectl port-forward -n prowler svc/prowler-ui 3000:3000
```

Then open http://localhost:3000 and login with the credentials you just created.

## 📥 Installation

### Add Helm Repository

```bash
helm repo add prowler-app https://promptlylabs.github.io/prowler-helm-chart
helm repo update
```

### Basic Installation

For development/testing with built-in databases:

```bash
helm install prowler prowler-app/prowler -n prowler --create-namespace
```

**Note:** Built-in databases use emptyDir storage by default (data is lost on pod restart). See [Database Configuration](#database-configuration) for persistence options.

### Production Installation

For production with external managed databases:

```bash
# 1. Create namespace
kubectl create namespace prowler

# 2. Create database secrets (see examples/values-external-db.yaml)
kubectl create secret generic prowler-postgres-secret -n prowler \
  --from-literal=POSTGRES_HOST=your-db-endpoint \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_ADMIN_USER=prowler_admin \
  --from-literal=POSTGRES_ADMIN_PASSWORD=your-password \
  --from-literal=POSTGRES_USER=prowler \
  --from-literal=POSTGRES_PASSWORD=your-password \
  --from-literal=POSTGRES_DB=prowler_db

kubectl create secret generic prowler-valkey-secret -n prowler \
  --from-literal=VALKEY_HOST=your-redis-endpoint \
  --from-literal=VALKEY_PORT=6379 \
  --from-literal=VALKEY_PASSWORD=your-password \
  --from-literal=VALKEY_DB=0

# 3. Install with production values
helm install prowler prowler-app/prowler \
  -n prowler \
  -f examples/values-production.yaml
```

See [examples/](examples/) directory for complete production configurations.

### Custom Installation

Install with custom values file:

```bash
# Create your custom values
cat > my-values.yaml <<EOF
api:
  replicaCount: 3
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi

worker:
  replicaCount: 5
  autoscaling:
    enabled: true
    maxReplicas: 20

ui:
  ingress:
    enabled: true
    hosts:
      - host: prowler.example.com
EOF

# Install with custom values
helm install prowler prowler-app/prowler \
  -n prowler \
  -f my-values.yaml
```

### Verify Installation

```bash
# Check pod status
kubectl get pods -n prowler

# Check all resources
kubectl get all -n prowler

# View logs
kubectl logs -n prowler -l app.kubernetes.io/component=api

# Run Helm tests
helm test prowler -n prowler
```

### Database Configuration

By default, this chart deploys [PostgreSQL](https://artifacthub.io/packages/helm/bitnami/postgresql) and [Valkey](https://artifacthub.io/packages/helm/bitnami/valkey) using Bitnami's charts.

**⚠️ Warning**: The bundled databases are **NOT production-ready**. For production deployments, use external managed databases.

**For Production:**
- AWS: RDS for PostgreSQL, ElastiCache for Redis
- Azure: Azure Database for PostgreSQL, Azure Cache for Redis
- GCP: Cloud SQL for PostgreSQL, Memorystore for Redis

See [examples/values-external-db.yaml](examples/values-external-db.yaml) for detailed external database configuration.

### Security

This chart implements several security features:

- **Auto-generated secrets**: Django keys are automatically generated during installation
- **Security contexts**: All pods run as non-root with dropped capabilities
- **Network policies**: Optional pod-to-pod communication control
- **RBAC**: Minimal read-only permissions for Kubernetes scanning
- **Pod Security Standards**: Compliance with restricted security profile

For detailed security configuration, see [SECURITY.md](SECURITY.md).

## ⚙️ Configuration

The chart is highly configurable through the `values.yaml` file. All configuration options are documented inline with comments and examples.

### Common Configurations

#### Resource Limits

```yaml
api:
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 512Mi

worker:
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

See [values.yaml](charts/prowler/values.yaml) for recommended values for each component.

#### Horizontal Autoscaling

```yaml
api:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70

worker:
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
```

#### Ingress with TLS

```yaml
ui:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: prowler.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: prowler-ui-tls
        hosts:
          - prowler.example.com

api:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: prowler-api.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: prowler-api-tls
        hosts:
          - prowler-api.example.com
```

#### Persistent Storage

```yaml
sharedStorage:
  type: persistentVolumeClaim
  persistentVolumeClaim:
    create: true
    storageClassName: "efs-sc"  # or your storage class
    accessMode: ReadWriteMany
    size: 50Gi
```

#### Network Policies

```yaml
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
```

**Note:** Requires CNI plugin with network policy support (Calico, Cilium, etc.)

#### Cloud Provider IAM

**AWS (IRSA):**
```yaml
worker:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/prowler-scanner
```

**Azure (Workload Identity):**
```yaml
worker:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "your-client-id"
  podLabels:
    azure.workload.identity/use: "true"
```

**GCP (Workload Identity):**
```yaml
worker:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: prowler@project.iam.gserviceaccount.com
```

### All Configuration Options

For complete configuration reference, see:
- [values.yaml](charts/prowler/values.yaml) - All available options with inline documentation
- [examples/values-production.yaml](examples/values-production.yaml) - Production-ready configuration
- [examples/values-external-db.yaml](examples/values-external-db.yaml) - External database setup

## 🔒 Security

This chart implements security best practices by default:

### Security Features

- ✅ **Pod Security Standards** - Restricted profile compliance
- ✅ **Non-root Containers** - All pods run as non-root user (UID 1000)
- ✅ **Dropped Capabilities** - All Linux capabilities dropped except required ones
- ✅ **Read-only Root Filesystem** - Where possible, filesystems are read-only
- ✅ **Seccomp Profiles** - RuntimeDefault seccomp profile applied
- ✅ **Auto-generated Secrets** - Django keys generated securely on install
- ✅ **No Hardcoded Secrets** - All secrets must be explicitly provided
- ✅ **RBAC** - Minimal permissions with fine-grained service accounts
- ✅ **Network Policies** - Optional pod-to-pod communication control

### Security Checklist for Production

- [ ] Use external managed databases (not built-in)
- [ ] Set strong PostgreSQL password
- [ ] Enable TLS/SSL for ingress
- [ ] Enable Network Policies
- [ ] Use external secrets management (e.g., External Secrets Operator)
- [ ] Enable audit logging
- [ ] Configure resource limits
- [ ] Use private container registries (if required)
- [ ] Enable Pod Disruption Budgets
- [ ] Configure backups for databases
- [ ] Review and customize RBAC permissions
- [ ] Enable admission controllers (OPA/Gatekeeper)

See [SECURITY.md](SECURITY.md) for comprehensive security documentation.

## 📦 Examples

Ready-to-use configuration examples are provided in the [examples/](examples/) directory:

### [values-production.yaml](examples/values-production.yaml)
Complete production-ready configuration with:
- External managed databases
- High availability (3+ replicas)
- Horizontal autoscaling
- Persistent storage
- Ingress with TLS
- Network policies
- Resource limits
- Pod Disruption Budgets

### [values-external-db.yaml](examples/values-external-db.yaml)
Focused guide for connecting to external databases:
- AWS RDS + ElastiCache configuration
- Azure Database + Cache for Redis setup
- GCP Cloud SQL + Memorystore setup
- Network configuration guidance
- Performance tuning recommendations
- Migration guide from built-in databases

See [examples/README.md](examples/README.md) for usage instructions and more examples.

## 📚 Documentation

### Core Documentation

- **[FAQ.md](FAQ.md)** - Frequently asked questions (20+ questions)
- **[UPGRADING.md](UPGRADING.md)** - Upgrade procedures and version-specific notes
- **[docs/troubleshooting.md](docs/troubleshooting.md)** - Common issues and solutions
- **[SECURITY.md](SECURITY.md)** - Security best practices and configuration
- **[CONTRIBUTING.md](.github/CONTRIBUTING.md)** - How to contribute to this project
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes

### Configuration Reference

- **[values.yaml](charts/prowler/values.yaml)** - Complete configuration options with inline docs
- **[examples/](examples/)** - Real-world configuration examples

### External Documentation

- **[Prowler Documentation](https://docs.prowler.com/)** - Official Prowler documentation
- **[Prowler GitHub](https://github.com/prowler-cloud/prowler)** - Prowler source code
- **[Artifact Hub](https://artifacthub.io/packages/helm/prowler-app/prowler)** - Chart on Artifact Hub

## 🔄 Upgrading

### Standard Upgrade

```bash
# Update Helm repository
helm repo update

# Check what will change
helm diff upgrade prowler prowler-app/prowler -n prowler

# Backup current configuration
helm get values prowler -n prowler > backup-values.yaml

# Perform upgrade
helm upgrade prowler prowler-app/prowler -n prowler --reuse-values
```

### Important Notes

- Always backup your data before upgrading
- Review [CHANGELOG.md](CHANGELOG.md) for breaking changes
- Test upgrades in non-production environment first
- Database migrations run automatically on upgrade

See [UPGRADING.md](UPGRADING.md) for detailed upgrade procedures, version-specific notes, and rollback instructions.

## 🔧 Troubleshooting

### Quick Diagnostics

```bash
# Check pod status
kubectl get pods -n prowler

# View recent events
kubectl get events -n prowler --sort-by='.lastTimestamp' | tail -20

# Check logs
kubectl logs -n prowler -l app.kubernetes.io/component=api --tail=50
kubectl logs -n prowler -l app.kubernetes.io/component=worker --tail=50

# Describe problematic pod
kubectl describe pod -n prowler <pod-name>
```

### Common Issues

#### Pods in CrashLoopBackOff
- Check database connection
- Verify secrets are created
- Check resource limits

See [docs/troubleshooting.md#pod-startup-problems](docs/troubleshooting.md#pod-startup-problems)

#### Login Issues
- Verify Django keys are generated
- Check API accessibility from UI
- Create superuser if not exists

See [docs/troubleshooting.md#authentication-and-login-problems](docs/troubleshooting.md#authentication-and-login-problems)

#### Workers Not Processing Tasks
- Check Valkey connection
- Verify worker pods are running
- Check worker-beat is scheduling

See [docs/troubleshooting.md#worker-and-celery-issues](docs/troubleshooting.md#worker-and-celery-issues)

### Complete Troubleshooting Guide

See [docs/troubleshooting.md](docs/troubleshooting.md) for comprehensive troubleshooting covering:
- Installation issues
- Pod startup problems
- Database connection issues
- Authentication problems
- Worker and Celery issues
- Storage and volume issues
- Networking and Ingress issues
- Performance problems
- Upgrade issues

## 🤝 Contributing

We welcome contributions! This project follows standard open-source contribution practices.

### Ways to Contribute

- 🐛 **Report Bugs** - Open an issue with details
- 💡 **Suggest Features** - Share your ideas
- 📝 **Improve Documentation** - Fix typos, add examples
- 🔧 **Submit Pull Requests** - Fix bugs or add features
- ⭐ **Star the Repository** - Show your support

### Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly (lint, template validation, local deployment)
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
6. Push to your fork
7. Open a Pull Request

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for detailed contribution guidelines, development setup, coding standards, and testing procedures.

## 💬 Getting Help

### Community Support

- **📖 Documentation** - Start with [FAQ.md](FAQ.md) and [docs/troubleshooting.md](docs/troubleshooting.md)
- **🐛 Bug Reports** - [GitHub Issues](https://github.com/promptlylabs/prowler-helm-chart/issues)
- **💬 Questions** - [GitHub Discussions](https://github.com/promptlylabs/prowler-helm-chart/discussions)
- **📧 Security Issues** - See [SECURITY.md](SECURITY.md)

### Before Opening an Issue

1. Check [FAQ.md](FAQ.md) for common questions
2. Search [existing issues](https://github.com/promptlylabs/prowler-helm-chart/issues)
3. Review [troubleshooting guide](docs/troubleshooting.md)
4. Collect debug information (logs, pod status, events)

### Commercial Support

For enterprise support, SLA-backed assistance, or custom development, contact [Prowler Cloud](https://prowler.com/).

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🌟 Acknowledgments

- [Prowler](https://github.com/prowler-cloud/prowler) - The amazing cloud security tool this chart deploys
- [Bitnami Charts](https://github.com/bitnami/charts) - PostgreSQL and Valkey dependencies
- All [contributors](https://github.com/promptlylabs/prowler-helm-chart/graphs/contributors) who have helped improve this project

## 🔗 Links

- **Chart Repository:** [prowler-helm-chart](https://github.com/promptlylabs/prowler-helm-chart)
- **Prowler:** [prowler-cloud/prowler](https://github.com/prowler-cloud/prowler)
- **Documentation:** [docs.prowler.com](https://docs.prowler.com/)
- **Artifact Hub:** [prowler-app/prowler](https://artifacthub.io/packages/helm/prowler-app/prowler)

---

**⭐ If you find this chart useful, please consider starring the repository!**
