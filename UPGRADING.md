# Upgrade Guide

This guide covers upgrading the Prowler Helm chart between versions, including breaking changes, migration steps, and best practices.

## Table of Contents

- [General Upgrade Process](#general-upgrade-process)
- [Pre-Upgrade Checklist](#pre-upgrade-checklist)
- [Upgrade Procedures](#upgrade-procedures)
- [Version-Specific Upgrade Notes](#version-specific-upgrade-notes)
- [Rollback Procedures](#rollback-procedures)
- [Best Practices](#best-practices)
- [Troubleshooting Upgrades](#troubleshooting-upgrades)

---

## General Upgrade Process

### Standard Upgrade

For most upgrades without breaking changes:

```bash
# 1. Update Helm repositories
helm repo update

# 2. Check what will change
helm diff upgrade prowler prowler/prowler -n prowler

# 3. Backup current configuration
helm get values prowler -n prowler > prowler-values-backup.yaml

# 4. Backup database (if using built-in PostgreSQL)
kubectl exec -n prowler prowler-postgresql-0 -- \
  pg_dump -U postgres prowler_db > prowler-db-backup-$(date +%Y%m%d).sql

# 5. Perform upgrade
helm upgrade prowler prowler/prowler -n prowler \
  --reuse-values \
  --wait \
  --timeout 10m

# 6. Verify upgrade
kubectl get pods -n prowler
kubectl rollout status deployment/prowler-api -n prowler
kubectl rollout status deployment/prowler-ui -n prowler
kubectl rollout status deployment/prowler-worker -n prowler

# 7. Test functionality
# - Login to UI
# - Create a test scan
# - Verify API endpoints
```

---

## Pre-Upgrade Checklist

Before upgrading, ensure you've completed these steps:

### 1. Review Release Notes

```bash
# Check release notes for breaking changes
helm show readme prowler/prowler --version X.Y.Z

# Review CHANGELOG
curl -s https://raw.githubusercontent.com/cytario/prowler-helm-chart/main/CHANGELOG.md
```

### 2. Backup Current State

```bash
# Export current Helm values
helm get values prowler -n prowler > prowler-values-$(date +%Y%m%d).yaml

# Export all Kubernetes resources
kubectl get all -n prowler -o yaml > prowler-k8s-$(date +%Y%m%d).yaml

# Backup PostgreSQL database
kubectl exec -n prowler prowler-postgresql-0 -- \
  pg_dump -U postgres -Fc prowler_db > prowler-db-$(date +%Y%m%d).dump

# For external databases, use your cloud provider's backup mechanism
```

### 3. Check Current Version

```bash
# Check installed chart version
helm list -n prowler

# Check application version
kubectl get deployment prowler-api -n prowler -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 4. Verify Cluster Health

```bash
# Check node status
kubectl get nodes

# Check resource availability
kubectl top nodes

# Check if PVCs are healthy
kubectl get pvc -n prowler

# Verify no pods are in bad state
kubectl get pods -n prowler
```

### 5. Plan Maintenance Window

- Notify users of potential downtime
- Plan upgrade during low-traffic period
- Allocate 30-60 minutes for upgrade and verification
- Have rollback plan ready

---

## Upgrade Procedures

### Upgrade Using Existing Values

```bash
# Reuse your existing values
helm upgrade prowler prowler/prowler \
  -n prowler \
  --reuse-values \
  --wait
```

### Upgrade with Values File

```bash
# Use your custom values file
helm upgrade prowler prowler/prowler \
  -n prowler \
  -f my-values.yaml \
  --wait
```

### Upgrade to Specific Version

```bash
# Upgrade to a specific chart version
helm upgrade prowler prowler/prowler \
  -n prowler \
  --version 1.2.3 \
  --reuse-values \
  --wait
```

### Upgrade with Value Overrides

```bash
# Override specific values during upgrade
helm upgrade prowler prowler/prowler \
  -n prowler \
  --reuse-values \
  --set api.replicaCount=5 \
  --set worker.autoscaling.enabled=true \
  --wait
```

### Dry Run Upgrade

```bash
# Preview what will change without applying
helm upgrade prowler prowler/prowler \
  -n prowler \
  --reuse-values \
  --dry-run \
  --debug
```

---

## Version-Specific Upgrade Notes

### Neo4j Addition (Current Version)

**New Feature:** Neo4j (DozerDB) is now included for Prowler's Attack Paths feature.

**What's New:**
- Neo4j is enabled by default (`neo4j.enabled=true`)
- Password is auto-generated if not provided
- Persistence is enabled by default

**Migration Steps:**
1. Upgrade normally - Neo4j will be deployed automatically:
   ```bash
   helm upgrade prowler charts/prowler \
     -n prowler \
     --reuse-values
   ```

2. Verify Neo4j is running:
   ```bash
   kubectl get pods -n prowler -l app.kubernetes.io/name=prowler-neo4j
   ```

**Disabling Neo4j (not recommended):**
If you don't need Attack Paths feature:
```bash
helm upgrade prowler charts/prowler \
  -n prowler \
  --reuse-values \
  --set neo4j.enabled=false
```

---

### Upgrading to v1.0.0 (Future Release)

**Breaking Changes:**
- TBD

**Migration Steps:**
1. TBD

---

### Upgrading from v0.x.x to v1.0.0 (When Available)

**Breaking Changes:**
- First stable release
- API changes may occur
- Configuration structure may change

**Migration Steps:**
Will be documented upon v1.0.0 release.

---

## Database Migrations

### Automatic Migrations

Django migrations run automatically on API pod startup. Monitor migration progress:

```bash
# Watch API pod logs during upgrade
kubectl logs -n prowler -l app.kubernetes.io/component=api -f

# Check migration status
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py showmigrations
```

### Manual Migration (If Needed)

If automatic migrations fail:

```bash
# Run migrations manually
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py migrate

# Check for unapplied migrations
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py showmigrations | grep "\[ \]"

# Fake a migration if needed (advanced)
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py migrate --fake <app_name> <migration_name>
```

---

## Upgrading Dependencies

### PostgreSQL Version Upgrade

**Warning:** PostgreSQL major version upgrades require careful planning and data migration.

#### Minor Version Upgrade (e.g., 15.1 → 15.3)

```bash
# Update chart dependencies
cd charts/prowler
helm dependency update

# Upgrade Prowler (will include new PostgreSQL version)
helm upgrade prowler . -n prowler --reuse-values
```

#### Major Version Upgrade (e.g., 14.x → 15.x)

Major PostgreSQL upgrades require data migration. Recommended approach:

1. **Backup existing database:**
   ```bash
   kubectl exec -n prowler prowler-postgresql-0 -- \
     pg_dumpall -U postgres > prowler-full-backup.sql
   ```

2. **Create new database with new version:**
   - Deploy new PostgreSQL instance with desired version
   - Restore data to new instance
   - Update Prowler to use new database

3. **Alternative: Use external managed database** (recommended for production)
   - Migrate to AWS RDS, Azure Database, or Cloud SQL
   - These services handle version upgrades automatically
   - See `examples/values-external-db.yaml`

### Valkey/Redis Version Upgrade

```bash
# Minor version upgrades are usually safe
helm upgrade prowler charts/prowler \
  --set valkey.image.tag=7.2.5 \
  -n prowler
```

For major version upgrades, review Valkey/Redis release notes for breaking changes.

---

## Rollback Procedures

### Quick Rollback

```bash
# Rollback to previous release
helm rollback prowler -n prowler

# Rollback to specific revision
helm history prowler -n prowler
helm rollback prowler <revision> -n prowler

# Verify rollback
kubectl get pods -n prowler -w
```

### Full Rollback with Database Restore

If database migrations caused issues:

```bash
# 1. Rollback Helm release
helm rollback prowler -n prowler

# 2. Restore database backup
kubectl exec -n prowler prowler-postgresql-0 -- psql -U postgres -d prowler_db < prowler-db-backup.sql

# 3. Restart all pods
kubectl rollout restart deployment -n prowler

# 4. Verify application state
kubectl get pods -n prowler
```

### Emergency Rollback

If pods are failing to start after upgrade:

```bash
# 1. Immediately rollback
helm rollback prowler -n prowler --wait

# 2. If rollback fails, force recreation
kubectl delete pod -n prowler -l app.kubernetes.io/instance=prowler

# 3. If still failing, restore from backup
helm uninstall prowler -n prowler
helm install prowler charts/prowler -n prowler -f prowler-values-backup.yaml

# 4. Restore database
kubectl exec -n prowler prowler-postgresql-0 -- \
  psql -U postgres -d prowler_db < prowler-db-backup.sql
```

---

## Best Practices

### 1. Always Test in Non-Production First

```bash
# Create staging environment
kubectl create namespace prowler-staging

# Install with production-like config
helm install prowler-staging charts/prowler \
  -n prowler-staging \
  -f values-staging.yaml

# Test upgrade in staging
helm upgrade prowler-staging charts/prowler \
  -n prowler-staging \
  --reuse-values

# Verify functionality
# Then proceed to production
```

### 2. Use Version Pinning

```yaml
# Chart.yaml or helmfile.yaml
version: 1.2.3  # Pin to specific version
```

### 3. Enable Automatic Backups

For production:
- Use external managed databases with automated backups
- Enable point-in-time recovery
- Test restore procedures regularly

### 4. Monitor During Upgrade

```bash
# Terminal 1: Watch pods
kubectl get pods -n prowler -w

# Terminal 2: Watch events
kubectl get events -n prowler -w

# Terminal 3: Monitor logs
kubectl logs -n prowler -l app.kubernetes.io/component=api -f

# Terminal 4: Check metrics
kubectl top pods -n prowler
```

### 5. Implement Health Checks

Ensure your values include proper health checks:

```yaml
api:
  startupProbe:
    enabled: true
    initialDelaySeconds: 10
  livenessProbe:
    enabled: true
  readinessProbe:
    enabled: true
```

### 6. Use Gradual Rollout

For large deployments:

```yaml
api:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

This ensures zero-downtime upgrades.

### 7. Verify Compatibility

Before upgrading, check:
- Kubernetes version compatibility
- Helm version requirements
- Dependent chart versions
- Custom configurations

### 8. Document Custom Changes

Keep a separate document of your custom configurations:

```yaml
# my-customizations.yaml
# Custom resource limits for our environment
api:
  replicaCount: 5
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
```

---

## Troubleshooting Upgrades

### Upgrade Hangs or Times Out

```bash
# Check pod status
kubectl get pods -n prowler

# Check events
kubectl get events -n prowler --sort-by='.lastTimestamp'

# Check resource constraints
kubectl describe pod -n prowler <pod-name>

# Force timeout and rollback
helm rollback prowler -n prowler
```

### Pods CrashLoopBackOff After Upgrade

```bash
# Check logs
kubectl logs -n prowler -l app.kubernetes.io/component=api --tail=100

# Common causes:
# 1. Migration failures - check API logs
# 2. Invalid configuration - verify values
# 3. Resource limits - check pod resource usage

# Quick fix: rollback
helm rollback prowler -n prowler
```

### Database Migration Errors

```bash
# Check migration status
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py showmigrations

# View migration history
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py migrate --list

# Check for migration conflicts
kubectl logs -n prowler -l app.kubernetes.io/component=api | grep -i migration

# Rollback database (if needed)
kubectl exec -n prowler deployment/prowler-api -- \
  python manage.py migrate <app_name> <previous_migration>
```

### ConfigMap/Secret Not Updated

```bash
# Verify ConfigMap changes
kubectl get configmap prowler-api -n prowler -o yaml

# Force pod restart to pick up changes
kubectl rollout restart deployment/prowler-api -n prowler
kubectl rollout restart deployment/prowler-ui -n prowler
kubectl rollout restart deployment/prowler-worker -n prowler

# Note: ConfigMap checksums should trigger automatic restart
# If not working, check deployment annotations
```

### PVC Issues After Upgrade

```bash
# Check PVC status
kubectl get pvc -n prowler

# Check PV status
kubectl get pv

# If PVC is stuck in Terminating:
kubectl patch pvc <pvc-name> -n prowler -p '{"metadata":{"finalizers":null}}'

# Recreate if needed (data loss warning!)
kubectl delete pvc <pvc-name> -n prowler
helm upgrade prowler charts/prowler -n prowler --reuse-values
```

---

## Upgrade Verification Checklist

After completing an upgrade:

- [ ] All pods are running: `kubectl get pods -n prowler`
- [ ] No error logs: `kubectl logs -n prowler -l app.kubernetes.io/component=api --tail=50`
- [ ] Database migrations completed: Check API logs for "Applying migrations..."
- [ ] UI accessible: Open browser and verify login page loads
- [ ] API accessible: `curl http://prowler-api:8080/api/health/`
- [ ] Login works: Test with valid credentials
- [ ] Create test scan: Verify worker functionality
- [ ] Review scan results: Ensure data processing works
- [ ] Check metrics: Monitor resource usage
- [ ] Verify persistence: Check that existing data is intact

---

## Getting Help

If you encounter issues during upgrade:

1. **Check Troubleshooting Guide:** [docs/troubleshooting.md](docs/troubleshooting.md)
2. **Search Issues:** [GitHub Issues](https://github.com/cytario/prowler-helm-chart/issues)
3. **Ask Community:** [GitHub Discussions](https://github.com/cytario/prowler-helm-chart/discussions)
4. **Review Logs:** Collect debug information (see troubleshooting guide)

When reporting upgrade issues, include:
- Source version (before upgrade)
- Target version (attempted upgrade)
- Helm command used
- Error messages and logs
- Kubernetes version
- Cloud provider (if applicable)

---

## Additional Resources

- [Helm Upgrade Documentation](https://helm.sh/docs/helm/helm_upgrade/)
- [Kubernetes Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [PostgreSQL Upgrade Guide](https://www.postgresql.org/docs/current/upgrading.html)
- [CHANGELOG.md](CHANGELOG.md) - Detailed version history
