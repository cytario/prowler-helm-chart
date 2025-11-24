<!-- 
This README is the one shown on Artifact Hub.
Images should use absolute URLs.
-->

# Prowler Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![AppVersion: 5.5.1](https://img.shields.io/badge/AppVersion-5.5.1-informational?style=flat-square)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/prowler-app)](https://artifacthub.io/packages/helm/prowler-app/prowler)

Prowler is an Open Cloud Security tool for AWS, Azure, GCP and Kubernetes. It helps for continuous monitoring, security assessments and audits, incident response, compliance, hardening and forensics readiness. Includes CIS, NIST 800, NIST CSF, CISA, FedRAMP, PCI-DSS, GDPR, HIPAA, FFIEC, SOC2, GXP, Well-Architected Security, ENS and more.

This is a Chart for the [Prowler App](https://docs.prowler.com/projects/prowler-open-source/en/latest/#prowler-app), not the [Prowler Dashboard](https://docs.prowler.com/projects/prowler-open-source/en/latest/#prowler-dashboard).

## Architecture

The Prowler App consists of three main components:

- **Prowler UI**: A user-friendly web interface for running Prowler and viewing results, powered by Next.js.
- **Prowler API**: The backend API that executes Prowler scans and stores the results, built with Django REST Framework.
- **Prowler SDK**: A Python SDK that integrates with the Prowler CLI for advanced functionality.

The app leverages the following supporting infrastructure:

- **PostgreSQL**: Used for persistent storage of scan results.
- **Celery Workers**: Facilitate asynchronous execution of Prowler scans.
- **Valkey**: An in-memory database serving as a message broker for the Celery workers.

![prowler architecture](https://promptlylabs.github.io/prowler-helm-chart/docs/images/architecture.png)

## Setup

### Quick Start

Install the chart with default settings:

```bash
helm repo add prowler-app https://promptlylabs.github.io/prowler-helm-chart
helm repo update
helm install prowler prowler-app/prowler
```

### Prerequisites

Prowler requires:
- Kubernetes 1.19+
- Helm 3.0+
- PostgreSQL database
- Valkey/Redis instance

### Database Configuration

**⚠️ Important**: This chart requires external PostgreSQL and Valkey/Redis instances. You must provide these databases before installing the chart. Managed databases (AWS RDS, Azure Database, GCP Cloud SQL) are recommended for production deployments.

#### External Database Configuration

This chart uses external databases by default. Create the required secrets with your database credentials:

**PostgreSQL Secret:**

```bash
kubectl create secret generic prowler-postgres-secret -n prowler \
  --from-literal=POSTGRES_HOST=your-postgres-host.example.com \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_ADMIN_USER=admin \
  --from-literal=POSTGRES_ADMIN_PASSWORD=admin-password \
  --from-literal=POSTGRES_USER=prowler \
  --from-literal=POSTGRES_PASSWORD=prowler-password \
  --from-literal=POSTGRES_DB=prowler_db
```

**Valkey/Redis Secret:**

```bash
kubectl create secret generic prowler-valkey-secret -n prowler \
  --from-literal=VALKEY_HOST=your-redis-host.example.com \
  --from-literal=VALKEY_PORT=6379 \
  --from-literal=VALKEY_PASSWORD=your-password \
  --from-literal=VALKEY_DB=0
```

**Note:** If your Redis/Valkey instance doesn't require authentication, you can omit `VALKEY_PASSWORD`.

**Required PostgreSQL Permissions:**
- The `POSTGRES_ADMIN_USER` needs: `CREATE`, `ALTER`, `DROP` on the database (for migrations)
- The `POSTGRES_USER` will be created by the admin user with necessary permissions

The credentials are automatically loaded from these secrets via `secretKeyRef` in the deployments.

For detailed examples with cloud-specific configurations (AWS RDS, Azure Database, GCP Cloud SQL), see [examples/](../../examples/).

### Security

This chart implements several security features:

- **Auto-generated secrets**: Django keys are automatically generated during installation
- **Security contexts**: All pods run as non-root with dropped capabilities
- **Network policies**: Optional pod-to-pod communication control
- **RBAC**: Minimal read-only permissions for Kubernetes scanning
- **Pod Security Standards**: Compliance with restricted security profile

For detailed security configuration, see [SECURITY.md](https://github.com/promptlylabs/prowler-helm-chart/blob/main/SECURITY.md).

### Configuration

The chart can be customized using values. See `values.yaml` for all available options.

Common configurations:

```yaml
# Enable network policies
api:
  networkPolicy:
    enabled: true

# Configure resource limits
api:
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 512Mi

# Use external databases
postgresql:
  enabled: false

valkey:
  enabled: false
```

## Security

See [SECURITY.md](https://github.com/promptlylabs/prowler-helm-chart/blob/main/SECURITY.md) for comprehensive security documentation including:
- Security features overview
- Best practices for production deployments
- Secrets management
- Network security configuration
- RBAC configuration
- Security checklist

## Contributing

Feel free to contact the maintainer of this repository for any questions or concerns. Contributions are encouraged and appreciated.
