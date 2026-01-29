# Troubleshooting Guide

This guide covers common issues you may encounter when deploying and operating the Prowler Helm chart, along with their solutions.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Pod Startup Problems](#pod-startup-problems)
- [Database Connection Issues](#database-connection-issues)
- [Authentication and Login Problems](#authentication-and-login-problems)
- [Worker and Celery Issues](#worker-and-celery-issues)
- [Storage and Volume Issues](#storage-and-volume-issues)
- [Networking and Ingress Issues](#networking-and-ingress-issues)
- [Performance Problems](#performance-problems)
- [Upgrade Issues](#upgrade-issues)
- [Neo4j Issues](#neo4j-issues)
- [Getting Help](#getting-help)

---

## Installation Issues

### Helm Install Fails with "rendered manifests contain a resource that already exists"

**Symptoms:**
```
Error: INSTALLATION FAILED: rendered manifests contain a resource that already exists
```

**Cause:** Previous installation wasn't fully cleaned up.

**Solution:**
```bash
# Check for existing resources
kubectl get all -n prowler
kubectl get pvc -n prowler
kubectl get secrets -n prowler

# Clean up
helm uninstall prowler -n prowler
kubectl delete pvc -n prowler --all
kubectl delete namespace prowler

# Try again
helm install prowler charts/prowler -n prowler --create-namespace
```

---

### Helm Install Fails with "no matches for kind PodDisruptionBudget"

**Symptoms:**
```
Error: unable to build kubernetes objects: no matches for kind "PodDisruptionBudget"
in version "policy/v1"
```

**Cause:** Kubernetes version is too old (< 1.21).

**Solution:**
```bash
# Check Kubernetes version
kubectl version --short

# Option 1: Upgrade Kubernetes to 1.21+
# Option 2: Disable PodDisruptionBudgets
helm install prowler charts/prowler \
  --set api.podDisruptionBudget.enabled=false \
  --set ui.podDisruptionBudget.enabled=false \
  --set worker.podDisruptionBudget.enabled=false \
  -n prowler
```

---

### PostgreSQL Password Not Set Error

**Symptoms:**
```
Error: INSTALLATION FAILED: execution error at (prowler/charts/postgresql/templates/NOTES.txt:...)
Please set a password for the PostgreSQL chart
```

**Cause:** PostgreSQL chart requires password to be explicitly set for security.

**Solution:**
```bash
# Generate a secure password
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Install with password
helm install prowler charts/prowler \
  --set postgresql.global.postgresql.auth.postgresPassword="$POSTGRES_PASSWORD" \
  -n prowler
```

---

## Pod Startup Problems

### API Pod Stuck in CrashLoopBackOff

**Symptoms:**
```bash
$ kubectl get pods -n prowler
NAME                           READY   STATUS             RESTARTS   AGE
prowler-api-xxxxx-xxxxx        0/1     CrashLoopBackOff   5          5m
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -n prowler -l app.kubernetes.io/component=api --tail=50

# Check pod events
kubectl describe pod -n prowler -l app.kubernetes.io/component=api
```

**Common Causes:**

#### 1. Database Migration Failures

**Logs show:**
```
django.db.utils.OperationalError: FATAL: password authentication failed for user "prowler_admin"
```

**Solution:**
```bash
# Verify external database secrets exist and are correct
kubectl get secret prowler-postgres-secret -n prowler
kubectl describe secret prowler-postgres-secret -n prowler

kubectl get secret prowler-valkey-secret -n prowler
kubectl describe secret prowler-valkey-secret -n prowler

# Check specific credential
kubectl get secret prowler-postgres-secret -n prowler -o jsonpath='{.data.POSTGRES_ADMIN_PASSWORD}' | base64 -d
```

#### 2. Invalid Django Keys

**Logs show:**
```
Token generation failed due to invalid key configuration
ValueError: Could not deserialize key data
```

**Cause:** Django keys were not properly generated or are in wrong format.

**Solution:**
```bash
# Check if pre-install job ran successfully
kubectl get jobs -n prowler
kubectl logs -n prowler job/prowler-generate-keys

# If job failed, delete it and let it retry
kubectl delete job prowler-generate-keys -n prowler

# Upgrade to trigger job recreation
helm upgrade prowler charts/prowler -n prowler --reuse-values
```

#### 3. Missing Required Environment Variables

**Logs show:**
```
KeyError: 'DJANGO_ALLOWED_HOSTS'
```

**Solution:**
```bash
# Check ConfigMap
kubectl get configmap prowler-api -n prowler -o yaml

# Verify all required variables are set
kubectl describe configmap prowler-api -n prowler
```

---

### Worker Beat Pod CrashLoopBackOff

**Symptoms:**
Worker Beat pod keeps restarting.

**Diagnosis:**
```bash
kubectl logs -n prowler -l app.kubernetes.io/component=worker-beat --tail=50
```

**Common Causes:**

#### 1. Database Connection Failure

**Logs show:**
```
could not connect to server: Connection refused
```

**Solution:**
```bash
# Verify PostgreSQL is running
kubectl get pods -n prowler -l app.kubernetes.io/name=postgresql

# Check connectivity from worker-beat pod
kubectl exec -n prowler -it deployment/prowler-worker-beat -- \
  nc -zv prowler-postgresql 5432

# Verify credentials in secret
kubectl get secret prowler-api-postgres -n prowler -o yaml
```

#### 2. Valkey/Redis Connection Failure

**Logs show:**
```
Error 111 connecting to prowler-valkey:6379. Connection refused.
```

**Solution:**
```bash
# Verify Valkey is running
kubectl get pods -n prowler -l app.kubernetes.io/name=valkey

# Check service
kubectl get svc prowler-valkey -n prowler

# Test connectivity
kubectl exec -n prowler -it deployment/prowler-worker-beat -- \
  nc -zv prowler-valkey 6379
```

---

### Worker Pods Not Starting

**Symptoms:**
```bash
$ kubectl get pods -n prowler
NAME                              READY   STATUS    RESTARTS   AGE
prowler-worker-xxxxx-xxxxx        0/1     Pending   0          5m
```

**Diagnosis:**
```bash
kubectl describe pod -n prowler -l app.kubernetes.io/component=worker
```

**Common Causes:**

#### 1. Insufficient Resources

**Events show:**
```
0/3 nodes are available: 3 Insufficient cpu, 3 Insufficient memory
```

**Solution:**
```bash
# Check node resources
kubectl top nodes

# Option 1: Reduce resource requests
helm upgrade prowler charts/prowler \
  --set worker.resources.requests.cpu=250m \
  --set worker.resources.requests.memory=256Mi \
  -n prowler

# Option 2: Add more nodes to cluster
```

#### 2. PersistentVolumeClaim Pending

**Events show:**
```
persistentvolumeclaim "prowler-shared-storage" not found
```

**Solution:**
```bash
# Check PVC status
kubectl get pvc -n prowler

# If using ReadWriteMany, ensure storage class supports it
kubectl get sc

# Option 1: Use emptyDir for testing
helm upgrade prowler charts/prowler \
  --set sharedStorage.type=emptyDir \
  -n prowler

# Option 2: Configure proper storage class
helm upgrade prowler charts/prowler \
  --set sharedStorage.persistentVolumeClaim.storageClassName=nfs-client \
  -n prowler
```

---

## Database Connection Issues

### "FATAL: database does not exist"

**Symptoms:**
```
django.db.utils.OperationalError: FATAL: database "prowler_db" does not exist
```

**Solution:**

For built-in PostgreSQL:
```bash
# Database should be created automatically
# If not, create manually:
kubectl exec -it -n prowler prowler-postgresql-0 -- psql -U postgres -c "CREATE DATABASE prowler_db;"
```

For external PostgreSQL:
```bash
# Connect to your database and create:
psql -h your-db-endpoint -U postgres
CREATE DATABASE prowler_db;
```

---

### "FATAL: role does not exist"

**Symptoms:**
```
FATAL: role "prowler_admin" does not exist
```

**Solution:**

For external PostgreSQL:
```bash
# Create the admin user with necessary privileges:
psql -h your-db-endpoint -U postgres -d prowler_db
CREATE USER prowler_admin WITH PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE prowler_db TO prowler_admin;
GRANT ALL ON SCHEMA public TO prowler_admin;
```

---

### Connection Pool Exhausted

**Symptoms:**
```
FATAL: remaining connection slots are reserved for non-replication superuser connections
```

**Cause:** Too many connections to PostgreSQL.

**Solution:**
```bash
# Check max connections setting
kubectl exec -it -n prowler prowler-postgresql-0 -- \
  psql -U postgres -c "SHOW max_connections;"

# Reduce number of API/Worker replicas
helm upgrade prowler charts/prowler \
  --set api.replicaCount=2 \
  --set worker.replicaCount=2 \
  -n prowler

# Or increase max_connections (external PostgreSQL)
# For RDS: Modify parameter group
# For Cloud SQL: Modify instance flags
```

---

## Authentication and Login Problems

### Login Returns "Token generation failed"

**Symptoms:**
API returns error when trying to authenticate:
```json
{
  "errors": [{
    "detail": "Token generation failed due to invalid key configuration"
  }]
}
```

**Cause:** Django JWT keys are invalid or missing.

**Solution:**
```bash
# Check if keys secret exists and is valid
kubectl get secret prowler-api-django-config-keys -n prowler
kubectl get secret prowler-api-django-config-keys -n prowler -o jsonpath='{.data.DJANGO_JWT_KEY}' | base64 -d | wc -l

# Delete secret and let pre-install job regenerate
kubectl delete secret prowler-api-django-config-keys -n prowler
kubectl delete job prowler-generate-keys -n prowler

# Trigger regeneration
helm upgrade prowler charts/prowler -n prowler --reuse-values

# Wait for job to complete
kubectl wait --for=condition=complete --timeout=120s job/prowler-generate-keys -n prowler

# Restart API pods to load new keys
kubectl rollout restart deployment/prowler-api -n prowler
```

---

### "Invalid credentials" Error

**Symptoms:**
Login with correct username/password returns "Invalid credentials".

**Diagnosis:**
```bash
# Check if superuser exists
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(is_superuser=True).exists())"
```

**Solution:**
```bash
# Create superuser manually
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py createsuperuser
```

---

### UI Cannot Connect to API

**Symptoms:**
UI loads but shows connection error or 502 Bad Gateway.

**Diagnosis:**
```bash
# Check API service
kubectl get svc prowler-api -n prowler

# Check if API pods are ready
kubectl get pods -n prowler -l app.kubernetes.io/component=api

# Check UI environment variables
kubectl exec -n prowler deployment/prowler-ui -- env | grep API
```

**Solution:**
```bash
# Verify API_URL in UI ConfigMap
kubectl get configmap prowler-ui -n prowler -o yaml | grep API_URL

# Should be internal service address for in-cluster:
# http://prowler-api:8080

# If using Ingress, update to external URL:
helm upgrade prowler charts/prowler \
  --set ui.config.NEXT_PUBLIC_API_URL=https://prowler-api.example.com \
  -n prowler
```

---

## Worker and Celery Issues

### Tasks Not Being Processed

**Symptoms:**
Scans are queued but never execute.

**Diagnosis:**
```bash
# Check worker pods
kubectl get pods -n prowler -l app.kubernetes.io/component=worker

# Check worker logs
kubectl logs -n prowler -l app.kubernetes.io/component=worker --tail=50

# Exec into worker and check Celery status
kubectl exec -n prowler -it deployment/prowler-worker -- \
  celery -A config inspect active
```

**Common Causes:**

#### 1. Workers Not Connected to Queue

**Solution:**
```bash
# Verify Valkey connection
kubectl exec -n prowler -it deployment/prowler-worker -- \
  python -c "import redis; r = redis.Redis(host='prowler-valkey', port=6379); r.ping()"

# Check CELERY_BROKER_URL
kubectl get configmap prowler-api -n prowler -o yaml | grep CELERY
```

#### 2. Worker Beat Not Running

**Solution:**
```bash
# Check worker-beat status
kubectl get pods -n prowler -l app.kubernetes.io/component=worker-beat

# Check beat logs
kubectl logs -n prowler -l app.kubernetes.io/component=worker-beat --tail=50

# Verify beat is scheduling tasks
kubectl exec -n prowler -it deployment/prowler-worker-beat -- \
  celery -A config inspect scheduled
```

---

### Worker Memory Issues / OOMKilled

**Symptoms:**
```bash
$ kubectl get pods -n prowler
NAME                              READY   STATUS      RESTARTS   AGE
prowler-worker-xxxxx-xxxxx        0/1     OOMKilled   5          10m
```

**Cause:** Worker exceeded memory limit during scan execution.

**Solution:**
```bash
# Increase worker memory limits
helm upgrade prowler charts/prowler \
  --set worker.resources.limits.memory=4Gi \
  --set worker.resources.requests.memory=1Gi \
  -n prowler

# Or reduce concurrent tasks per worker
# Add environment variable to limit concurrency:
helm upgrade prowler charts/prowler \
  --set worker.env.CELERYD_CONCURRENCY=2 \
  -n prowler
```

---

## Storage and Volume Issues

### "Unable to attach or mount volumes"

**Symptoms:**
```
Warning  FailedMount  2m    kubelet  Unable to attach or mount volumes:
unmounted volumes=[shared-storage]
```

**Diagnosis:**
```bash
# Check PVC status
kubectl get pvc -n prowler

# Check PV status
kubectl get pv

# Check storage class
kubectl get sc
kubectl describe sc <storage-class-name>
```

**Solutions:**

#### ReadWriteMany Not Supported

**Error:**
```
waiting for a volume to be created, either by external provisioner
"ebs.csi.aws.com" or manually created by system administrator
```

**Solution:**
```bash
# AWS EBS doesn't support ReadWriteMany
# Option 1: Use EFS
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/deploy/kubernetes/base/csidriver.yaml

# Option 2: Use emptyDir (data not persisted)
helm upgrade prowler charts/prowler \
  --set sharedStorage.type=emptyDir \
  -n prowler

# Option 3: Use ReadWriteOnce with single API/Worker replica
helm upgrade prowler charts/prowler \
  --set sharedStorage.persistentVolumeClaim.accessMode=ReadWriteOnce \
  --set api.replicaCount=1 \
  --set worker.replicaCount=1 \
  -n prowler
```

---

### Volume Mount Permission Denied

**Symptoms:**
```
Error: failed to start container: Error response from daemon:
error while creating mount: permission denied
```

**Cause:** Pod security context user doesn't have permissions on volume.

**Solution:**
```bash
# Update fsGroup in pod security context
helm upgrade prowler charts/prowler \
  --set api.podSecurityContext.fsGroup=1000 \
  --set worker.podSecurityContext.fsGroup=1000 \
  -n prowler
```

---

## Networking and Ingress Issues

### Ingress Returns 404 Not Found

**Symptoms:**
Accessing `https://prowler.example.com` returns 404.

**Diagnosis:**
```bash
# Check ingress
kubectl get ingress -n prowler
kubectl describe ingress prowler-ui -n prowler

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

**Solution:**
```bash
# Verify ingress class exists
kubectl get ingressclass

# Update ingress class name
helm upgrade prowler charts/prowler \
  --set ui.ingress.className=nginx \
  --set api.ingress.className=nginx \
  -n prowler

# Verify hosts match
helm upgrade prowler charts/prowler \
  --set ui.ingress.hosts[0].host=prowler.example.com \
  -n prowler
```

---

### TLS Certificate Issues

**Symptoms:**
Browser shows "Your connection is not private" or certificate errors.

**Diagnosis:**
```bash
# Check cert-manager if using
kubectl get certificate -n prowler
kubectl describe certificate prowler-ui-tls -n prowler

# Check certificate challenges
kubectl get challenges -n prowler
```

**Solution:**
```bash
# Verify cert-manager is installed
kubectl get pods -n cert-manager

# Check ClusterIssuer exists
kubectl get clusterissuer letsencrypt-prod

# Delete certificate to retry
kubectl delete certificate prowler-ui-tls -n prowler

# Check DNS is pointing to ingress
nslookup prowler.example.com
```

---

### Network Policy Blocking Traffic

**Symptoms:**
Pods can't communicate despite being on same cluster.

**Diagnosis:**
```bash
# Check if network policies are enabled
kubectl get networkpolicy -n prowler

# Test connectivity
kubectl exec -n prowler -it deployment/prowler-api -- \
  nc -zv prowler-postgresql 5432
```

**Solution:**
```bash
# Temporarily disable network policies for testing
helm upgrade prowler charts/prowler \
  --set networkPolicy.enabled=false \
  -n prowler

# Or update policy to allow required traffic
# Edit networkpolicy manifest to add required egress rules
```

---

## Performance Problems

### Slow API Response Times

**Diagnosis:**
```bash
# Check API pod resources
kubectl top pod -n prowler -l app.kubernetes.io/component=api

# Check database performance
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py check --deploy
```

**Solutions:**

1. **Scale up API pods:**
   ```bash
   helm upgrade prowler charts/prowler \
     --set api.replicaCount=5 \
     -n prowler
   ```

2. **Increase resource limits:**
   ```bash
   helm upgrade prowler charts/prowler \
     --set api.resources.limits.cpu=4000m \
     --set api.resources.limits.memory=4Gi \
     -n prowler
   ```

3. **Enable autoscaling:**
   ```bash
   helm upgrade prowler charts/prowler \
     --set api.autoscaling.enabled=true \
     --set api.autoscaling.minReplicas=3 \
     --set api.autoscaling.maxReplicas=10 \
     -n prowler
   ```

---

### High Database Load

**Symptoms:**
Database CPU/memory at 100%, slow queries.

**Diagnosis:**
```bash
# For external database, check cloud provider metrics

# For built-in PostgreSQL:
kubectl exec -n prowler -it prowler-postgresql-0 -- \
  psql -U postgres -d prowler_db -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

**Solutions:**

1. **Add database indexes** (done by migrations)
2. **Scale to external managed database** (see examples/values-external-db.yaml)
3. **Enable connection pooling** (PgBouncer or RDS Proxy)
4. **Increase database resources**

---

## Upgrade Issues

### Helm Upgrade Fails with "cannot patch"

**Symptoms:**
```
Error: UPGRADE FAILED: cannot patch "prowler-api" with kind Deployment: ...
```

**Solution:**
```bash
# Force upgrade
helm upgrade prowler charts/prowler \
  -n prowler \
  --force

# If that doesn't work, delete and reinstall:
helm uninstall prowler -n prowler
# Backup data first!
helm install prowler charts/prowler -n prowler
```

---

### Database Migration Fails After Upgrade

**Symptoms:**
API pods fail with migration errors after chart upgrade.

**Solution:**
```bash
# Check migration status
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py showmigrations

# Run migrations manually
kubectl exec -n prowler -it deployment/prowler-api -- \
  python manage.py migrate

# If migrations fail, check logs:
kubectl logs -n prowler -l app.kubernetes.io/component=api --tail=100
```

---

### Pods Not Restarting After ConfigMap/Secret Changes

**Symptoms:**
Updated configuration but pods still using old config.

**Cause:** ConfigMap/Secret checksums in pod annotations ensure automatic restarts, but manual changes bypass this.

**Solution:**
```bash
# Manually restart affected deployments
kubectl rollout restart deployment/prowler-api -n prowler
kubectl rollout restart deployment/prowler-ui -n prowler
kubectl rollout restart deployment/prowler-worker -n prowler
kubectl rollout restart deployment/prowler-worker-beat -n prowler

# Verify rollout
kubectl rollout status deployment/prowler-api -n prowler
```

---

## Neo4j Issues

### Neo4j Pod Not Starting

**Symptoms:**
```bash
$ kubectl get pods -n prowler
NAME                           READY   STATUS             RESTARTS   AGE
prowler-neo4j-xxxxx-xxxxx      0/1     CrashLoopBackOff   5          5m
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-neo4j --tail=50

# Check pod events
kubectl describe pod -n prowler -l app.kubernetes.io/name=prowler-neo4j
```

**Common Causes:**

#### 1. Memory Issues

**Logs show:**
```
Java heap space error
OutOfMemoryError
```

**Solution:**
```bash
# Increase Neo4j memory limits
helm upgrade prowler charts/prowler \
  --set neo4j.resources.limits.memory=8Gi \
  --set neo4j.config.heapMaxSize=4G \
  --set neo4j.config.pagecacheSize=2G \
  -n prowler
```

---

### API/Worker Cannot Connect to Neo4j

**Symptoms:**
API or Worker logs show Neo4j connection errors.

**Diagnosis:**
```bash
# Check Neo4j service
kubectl get svc prowler-neo4j -n prowler

# Test connectivity from API pod
kubectl exec -n prowler -it deployment/prowler-api -- \
  nc -zv prowler-neo4j 7687
```

**Solution:**
```bash
# Verify Neo4j is running
kubectl get pods -n prowler -l app.kubernetes.io/name=prowler-neo4j

# Check Neo4j logs
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-neo4j --tail=50

# Restart Neo4j if needed
kubectl rollout restart deployment/prowler-neo4j -n prowler
```

---

### Neo4j Data Loss After Restart

**Cause:** Persistence is disabled (using emptyDir).

**Solution:**
```bash
# Enable persistent storage
helm upgrade prowler charts/prowler \
  --set neo4j.persistence.enabled=true \
  --set neo4j.persistence.size=20Gi \
  -n prowler
```

---

### Attack Paths Feature Not Working

**Symptoms:**
Attack Paths feature shows errors or no data.

**Diagnosis:**
```bash
# Check if Neo4j is enabled
helm get values prowler -n prowler | grep neo4j

# Check Neo4j connectivity
kubectl exec -n prowler -it deployment/prowler-api -- \
  env | grep NEO4J
```

**Solution:**
Ensure Neo4j is enabled and properly configured:
```bash
helm upgrade prowler charts/prowler \
  --set neo4j.enabled=true \
  --set neo4j.auth.password=your-password \
  -n prowler
```

---

## Getting Help

### Debug Information Collection

When reporting issues, collect this information:

```bash
# Helm release information
helm list -n prowler
helm get values prowler -n prowler
helm get manifest prowler -n prowler > prowler-manifest.yaml

# Kubernetes version
kubectl version

# Pod status
kubectl get pods -n prowler -o wide

# Pod logs (last 100 lines)
kubectl logs -n prowler -l app.kubernetes.io/component=api --tail=100 > api-logs.txt
kubectl logs -n prowler -l app.kubernetes.io/component=ui --tail=100 > ui-logs.txt
kubectl logs -n prowler -l app.kubernetes.io/component=worker --tail=100 > worker-logs.txt
kubectl logs -n prowler -l app.kubernetes.io/component=worker-beat --tail=100 > worker-beat-logs.txt

# Pod descriptions
kubectl describe pod -n prowler -l app.kubernetes.io/component=api > api-describe.txt

# Events
kubectl get events -n prowler --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n prowler
kubectl top nodes
```

### Community Support

- **GitHub Issues:** [prowler-helm-chart/issues](https://github.com/promptlylabs/prowler-helm-chart/issues)
- **GitHub Discussions:** [prowler-helm-chart/discussions](https://github.com/promptlylabs/prowler-helm-chart/discussions)
- **Prowler Documentation:** [docs.prowler.com](https://docs.prowler.com/)

### Commercial Support

For production deployments requiring SLA-backed support, contact Prowler Cloud.

---

## Common Commands Reference

```bash
# View all Prowler resources
kubectl get all -n prowler

# Check pod logs (follow)
kubectl logs -n prowler -l app.kubernetes.io/component=api -f

# Exec into API pod
kubectl exec -n prowler -it deployment/prowler-api -- /bin/bash

# Port forward to API for local testing
kubectl port-forward -n prowler svc/prowler-api 8080:8080

# Port forward to UI
kubectl port-forward -n prowler svc/prowler-ui 3000:3000

# Check Helm release history
helm history prowler -n prowler

# Rollback to previous release
helm rollback prowler -n prowler

# Test Helm templates locally
helm template prowler charts/prowler -f my-values.yaml

# Validate Kubernetes manifests
helm template prowler charts/prowler -f my-values.yaml | kubeval
```
