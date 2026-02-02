# Security Guide

This document outlines the security features and best practices for deploying the Prowler Helm Chart.

## Table of Contents

- [Security Features](#security-features)
- [Security Best Practices](#security-best-practices)
- [Secrets Management](#secrets-management)
- [Network Security](#network-security)
- [RBAC Configuration](#rbac-configuration)
- [Pod Security](#pod-security)
- [Security Checklist](#security-checklist)
- [Reporting Vulnerabilities](#reporting-vulnerabilities)

## Security Features

### Automatic Secret Generation

The chart automatically generates Django secret keys during installation using a pre-install Job. This ensures:

- **No hardcoded secrets** in version control
- **Unique keys per installation**
- **Secure key generation** using OpenSSL

Keys are stored in a Kubernetes Secret and include:
- `DJANGO_TOKEN_SIGNING_KEY` - RSA private key for JWT signing
- `DJANGO_TOKEN_VERIFYING_KEY` - RSA public key for JWT verification
- `DJANGO_SECRETS_ENCRYPTION_KEY` - Encryption key for sensitive data

### Security Contexts

All pods run with restrictive security contexts:

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Required for application writes
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL
```

### Network Policies

Network policies can be enabled to restrict pod-to-pod communication:

```yaml
api:
  networkPolicy:
    enabled: true
```

When enabled, the following policies are applied:
- **UI**: Can communicate with API only
- **API**: Can communicate with PostgreSQL, Valkey, and Kubernetes API
- **Workers**: Can communicate with API, PostgreSQL, Valkey, and cloud provider APIs
- **Beat Worker**: Can communicate with PostgreSQL and Valkey

### RBAC

The chart creates a ClusterRole with minimal read-only permissions for Kubernetes scanning:

- Core resources: pods, configmaps, nodes, namespaces, services, serviceaccounts
- RBAC resources: roles, rolebindings, clusterroles, clusterrolebindings
- Apps resources: deployments, daemonsets, statefulsets, replicasets
- Networking resources: networkpolicies, ingresses
- Policy resources: podsecuritypolicies, poddisruptionbudgets

You can disable Kubernetes scanning RBAC if not needed:

```yaml
api:
  rbac:
    create: false
```

### Pod Security Standards

All pods are labeled for Pod Security Standards compliance:

```yaml
pod-security.kubernetes.io/enforce: restricted
```

Pods also include seccomp annotations for additional protection.

## Security Best Practices

### 1. Use External Databases

For production deployments, use external managed databases instead of the bundled PostgreSQL and Valkey:

```yaml
postgresql:
  enabled: false

valkey:
  enabled: false
```

Then create secrets with connection details to your external databases.

### 2. Enable Network Policies

Enable network policies to restrict pod-to-pod communication:

```yaml
api:
  networkPolicy:
    enabled: true
```

**Note**: Ensure your Kubernetes cluster has a network plugin that supports NetworkPolicy (e.g., Calico, Cilium, Weave Net).

### 3. Configure Resource Limits

Set appropriate resource limits to prevent resource exhaustion:

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

### 4. Enable TLS for Ingress

Configure TLS certificates for the UI and API ingresses:

```yaml
ui:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - host: prowler-ui.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: prowler-ui-tls
        hosts:
          - prowler-ui.example.com

api:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
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

### 5. Regular Updates

Keep the Prowler chart and application updated:

```bash
helm repo update
helm upgrade prowler prowler-app/prowler
```

### 6. Audit Logs

Enable audit logging in your Kubernetes cluster to track access to Prowler resources.

### 7. Namespace Isolation

Deploy Prowler in a dedicated namespace with appropriate RBAC:

```bash
kubectl create namespace prowler
helm install prowler prowler-app/prowler -n prowler
```

## Secrets Management

### Automatic Secret Generation

By default, Django secrets are generated automatically. If you need to provide your own secrets:

1. Set `api.djangoConfigKeys.create: false`
2. Create a secret manually:

```bash
# Generate keys
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic my-release-api-django-config-keys \
  --from-file=DJANGO_TOKEN_SIGNING_KEY=private.pem \
  --from-file=DJANGO_TOKEN_VERIFYING_KEY=public.pem \
  --from-literal=DJANGO_SECRETS_ENCRYPTION_KEY=$ENCRYPTION_KEY
```

### External Secrets

For production, consider using external secret management:

- **AWS Secrets Manager**: Use [External Secrets Operator](https://external-secrets.io/)
- **HashiCorp Vault**: Use [Vault Secrets Operator](https://github.com/hashicorp/vault-secrets-operator)
- **Azure Key Vault**: Use [Azure Key Vault Provider](https://github.com/Azure/secrets-store-csi-driver-provider-azure)
- **Google Secret Manager**: Use [External Secrets Operator](https://external-secrets.io/)

### Secret Rotation

To rotate Django secrets:

1. Delete the existing secret:
   ```bash
   kubectl delete secret my-release-api-django-config-keys
   ```

2. Upgrade the release to regenerate:
   ```bash
   helm upgrade prowler prowler-app/prowler
   ```

3. Restart all pods:
   ```bash
   kubectl rollout restart deployment -l app.kubernetes.io/instance=prowler
   ```

**Note**: Rotating secrets will invalidate all existing JWT tokens.

## Network Security

### Network Policy Requirements

To use network policies, your cluster must have a CNI plugin that supports them:

- Calico
- Cilium
- Weave Net
- Azure CNI (with Azure Network Policy Manager)
- GKE (with Network Policy enabled)

### Egress Control

By default, workers need egress access to:
- Cloud provider APIs (AWS, Azure, GCP) on port 443
- Kubernetes API on port 443/6443
- PostgreSQL on port 5432
- Valkey on port 6379

If you have strict egress requirements, configure additional egress rules:

```yaml
api:
  networkPolicy:
    enabled: true
    egress:
      # Allow specific cloud provider endpoints
      - to:
        - podSelector: {}
        ports:
        - protocol: TCP
          port: 443
```

## RBAC Configuration

### Minimal Permissions

The chart creates a ClusterRole with minimal permissions for Kubernetes scanning. If you need to reduce permissions further:

```yaml
api:
  rbac:
    create: true
    rules:
      # Add only the resources you want to scan
      - apiGroups: [""]
        resources: ["pods", "namespaces"]
        verbs: ["get", "list"]
```

### Disable Kubernetes Scanning

If you don't plan to scan Kubernetes resources:

```yaml
api:
  rbac:
    create: false
```

### Service Account Permissions

Workers don't need cluster-wide permissions by default. If you need workers to have Kubernetes access, configure accordingly.

## Pod Security

### Pod Security Standards

All pods comply with the `restricted` Pod Security Standard:

- Run as non-root user
- Drop all capabilities
- Use seccomp profile
- No privilege escalation
- Read-only root filesystem (where possible)

### Pod Security Admission

If your cluster uses Pod Security Admission, label your namespace:

```bash
kubectl label namespace prowler \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### AppArmor/SELinux

For additional security, configure AppArmor or SELinux profiles:

```yaml
api:
  podAnnotations:
    container.apparmor.security.beta.kubernetes.io/api: runtime/default

worker:
  podAnnotations:
    container.apparmor.security.beta.kubernetes.io/worker: runtime/default
```

## Security Checklist

Before deploying to production:

- [ ] Use external managed databases (PostgreSQL and Valkey/Redis)
- [ ] Enable network policies
- [ ] Configure resource limits for all components
- [ ] Enable TLS for ingresses
- [ ] Configure authentication (OAuth, SAML, etc.)
- [ ] Set up backup and disaster recovery
- [ ] Enable audit logging
- [ ] Review and configure RBAC permissions
- [ ] Implement secret rotation policy
- [ ] Configure monitoring and alerting
- [ ] Perform security scanning of container images
- [ ] Review and test disaster recovery procedures
- [ ] Document security configurations

## Reporting Vulnerabilities

If you discover a security vulnerability in the Prowler Helm Chart, please report it to:

- **Chart Issues**: [GitHub Issues](https://github.com/cytario/prowler-helm-chart/issues)
- **Prowler Application**: [Prowler Security Policy](https://github.com/prowler-cloud/prowler/security/policy)

Please do not disclose security vulnerabilities publicly until they have been addressed.

## Additional Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-best-practices/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Prowler Documentation](https://docs.prowler.com/)
