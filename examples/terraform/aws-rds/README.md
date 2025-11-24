# Prowler with AWS RDS PostgreSQL using Terraform

This example demonstrates a production-ready deployment of Prowler on AWS EKS with AWS RDS PostgreSQL as the database backend. This configuration provides enterprise-grade reliability, performance, and security.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                         │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                     VPC                                │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  EKS Cluster (Control Plane)                     │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Private Subnets (Worker Nodes)                  │  │ │
│  │  │  ┌─────────────────────────────────────────────┐ │  │ │
│  │  │  │  Prowler Pods                               │ │  │ │
│  │  │  │  ├─ UI (2 replicas)                         │ │  │ │
│  │  │  │  ├─ API (2 replicas)                        │ │  │ │
│  │  │  │  ├─ Worker (2 replicas)                     │ │  │ │
│  │  │  │  ├─ Worker Beat (1 replica)                 │ │  │ │
│  │  │  │  └─ Valkey (1 replica)                      │ │  │ │
│  │  │  └─────────────────────────────────────────────┘ │  │ │
│  │  └──────────────────────┬───────────────────────────┘  │ │
│  │                         │ PostgreSQL Protocol          │ │
│  │                         │ Port 5432                    │ │
│  │  ┌──────────────────────▼───────────────────────────┐  │ │
│  │  │  Database Subnets                                │  │ │
│  │  │  ┌─────────────────────────────────────────────┐ │  │ │
│  │  │  │  AWS RDS PostgreSQL                         │ │  │ │
│  │  │  │  ├─ Engine: PostgreSQL 16.3                 │ │  │ │
│  │  │  │  ├─ Multi-AZ: Yes                           │ │  │ │
│  │  │  │  ├─ Storage: gp3 (encrypted)                │ │  │ │
│  │  │  │  ├─ Backups: 7 days retention               │ │  │ │
│  │  │  │  └─ Performance Insights: Enabled           │ │  │ │
│  │  │  └─────────────────────────────────────────────┘ │  │ │
│  │  │                                                  │  │ │
│  │  │  Security Group: Allow 5432 from VPC CIDR        │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  CloudWatch Logs & Metrics                                  │
│  Performance Insights                                       │
│  Enhanced Monitoring                                        │
└─────────────────────────────────────────────────────────────┘
```

## Benefits of AWS RDS

1. **Managed Service**: AWS handles backups, patching, and maintenance
2. **High Availability**: Multi-AZ deployment with automatic failover
3. **Performance**: Optimized storage (gp3), Read Replicas support
4. **Security**: VPC isolation, encryption at rest, IAM authentication
5. **Monitoring**: CloudWatch, Performance Insights, Enhanced Monitoring
6. **Scalability**: Easy vertical and horizontal scaling
7. **Disaster Recovery**: Automated backups, point-in-time recovery

## Cost Estimate

Approximate monthly costs (us-east-1):
- RDS db.t3.medium (Multi-AZ): ~$140
- Storage (100GB gp3): ~$25
- Backups (7 days): ~$10
- Data transfer: Variable
- **Total**: ~$175-200/month

For production, consider:
- db.r6g.xlarge: ~$600/month
- 500GB storage: ~$125/month

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Existing EKS cluster
- VPC with:
  - At least 2 private subnets for RDS (different AZs)
  - Private subnets for EKS worker nodes
  - Proper routing and NAT gateways
- AWS IAM permissions for:
  - RDS (create, modify, delete)
  - EC2 (security groups, subnet groups)
  - IAM (roles, policies)
  - Secrets Manager (optional, for credential management)

## Usage

### 1. Get EKS Cluster Information

```bash
# Get EKS cluster details
export CLUSTER_NAME="my-eks-cluster"
export AWS_REGION="us-east-1"

# Get cluster endpoint
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'cluster.endpoint' \
  --output text

# Get cluster CA certificate
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'cluster.certificateAuthority.data' \
  --output text

# Get VPC ID
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text

# Get subnet IDs (filter for private subnets)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
  --output text
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "us-east-1"

# EKS Configuration (from step 1)
eks_cluster_name           = "my-eks-cluster"
eks_cluster_endpoint       = "https://xxxxx.eks.us-east-1.amazonaws.com"
eks_cluster_ca_certificate = "LS0tLS1CRUdJTi..."

# Network Configuration
vpc_id              = "vpc-xxxxx"
vpc_cidr            = "10.0.0.0/16"
database_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

# RDS Configuration
rds_instance_class    = "db.t3.medium"    # Adjust for production
rds_multi_az          = true
rds_master_password   = ""  # Leave empty for auto-generation
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan
```

Review the resources to be created:
- RDS DB Instance (Multi-AZ)
- RDS Subnet Group
- Security Group for RDS
- DB Parameter Group
- IAM Role for Enhanced Monitoring
- Kubernetes Secret (RDS credentials)
- Prowler Helm Release

### 5. Apply the Configuration

```bash
terraform apply
```

**⚠️ Note**: RDS creation takes 10-15 minutes. Type `yes` when prompted.

### 6. Verify Deployment

Check RDS status:

```bash
aws rds describe-db-instances \
  --db-instance-identifier prowler-postgres \
  --region us-east-1 \
  --query 'DBInstances[0].DBInstanceStatus'
```

Check Prowler pods:

```bash
kubectl get pods -n prowler
```

Verify database connection:

```bash
kubectl logs -n prowler -l app.kubernetes.io/name=prowler-api --tail=50 | grep -i "migration\|ready"
```

### 7. Access the Application

```bash
# Access UI
kubectl port-forward -n prowler svc/prowler-ui 3000:3000

# In another terminal, access API
kubectl port-forward -n prowler svc/prowler-api 8080:8080
```

Open:
- UI: http://localhost:3000
- API Docs: http://localhost:8080/api/v1/docs

## Configuration Options

### RDS Instance Sizing

Development:
```hcl
rds_instance_class        = "db.t3.small"
rds_allocated_storage     = 20
rds_multi_az              = false
rds_deletion_protection   = false
```

Production:
```hcl
rds_instance_class        = "db.r6g.xlarge"
rds_allocated_storage     = 500
rds_max_allocated_storage = 2000
rds_multi_az              = true
rds_deletion_protection   = true
```

High Performance:
```hcl
rds_instance_class = "db.r6g.2xlarge"
# Add Read Replicas (requires additional configuration)
```

### Security Hardening

Enable IAM authentication:
```hcl
# Add to aws_db_instance.prowler:
iam_database_authentication_enabled = true
```

Custom KMS key for encryption:
```hcl
kms_key_id          = aws_kms_key.rds.arn
storage_encrypted   = true
```

### Backup Strategy

Extended retention:
```hcl
rds_backup_retention_period = 30  # 30 days
```

Custom backup window:
```hcl
# Add to aws_db_instance.prowler:
backup_window      = "03:00-04:00"  # UTC
maintenance_window = "sun:04:00-sun:05:00"
```

## Monitoring and Observability

### CloudWatch Metrics

View RDS metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=prowler-postgres \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1
```

### Performance Insights

Access via AWS Console:
1. Navigate to RDS → prowler-postgres
2. Click "Performance Insights"
3. Analyze top SQL, wait events, and load

### Enhanced Monitoring

View OS-level metrics (CPU, memory, I/O) in CloudWatch or Performance Insights.

### Logs

View PostgreSQL logs:
```bash
aws rds describe-db-log-files \
  --db-instance-identifier prowler-postgres \
  --region us-east-1

aws rds download-db-log-file-portion \
  --db-instance-identifier prowler-postgres \
  --log-file-name error/postgresql.log.2025-01-18-00 \
  --region us-east-1
```

## Database Operations

### Connect to RDS

Via kubectl port-forward:
```bash
kubectl port-forward -n prowler \
  $(kubectl get pods -n prowler -l app.kubernetes.io/name=prowler-api -o jsonpath='{.items[0].metadata.name}') \
  5433:5432
```

Then:
```bash
PGPASSWORD=$(terraform output -raw rds_master_password) \
psql -h localhost -p 5433 -U prowler_admin -d prowler_db
```

Via bastion host (if configured):
```bash
psql -h prowler-postgres.xxxxx.us-east-1.rds.amazonaws.com \
     -U prowler_admin \
     -d prowler_db
```

### Backup and Restore

Manual snapshot:
```bash
aws rds create-db-snapshot \
  --db-instance-identifier prowler-postgres \
  --db-snapshot-identifier prowler-manual-snapshot-$(date +%Y%m%d-%H%M%S) \
  --region us-east-1
```

Restore from snapshot:
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prowler-postgres-restored \
  --db-snapshot-identifier prowler-manual-snapshot-20250118-120000 \
  --region us-east-1
```

Point-in-time recovery:
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prowler-postgres \
  --target-db-instance-identifier prowler-postgres-restored \
  --restore-time 2025-01-18T12:00:00Z \
  --region us-east-1
```

### Scaling

Vertical scaling:
```hcl
# In terraform.tfvars:
rds_instance_class = "db.r6g.2xlarge"
```

```bash
terraform apply
```

**⚠️ Note**: Scaling causes downtime (Multi-AZ minimizes this to seconds).

Horizontal scaling (Read Replicas):
```hcl
# Add to main.tf:
resource "aws_db_instance" "prowler_replica" {
  identifier             = "prowler-postgres-replica"
  replicate_source_db    = aws_db_instance.prowler.identifier
  instance_class         = var.rds_instance_class
  publicly_accessible    = false
  skip_final_snapshot    = true
}
```

## Disaster Recovery

### Automated Backups

Configured retention period (default: 7 days):
```bash
aws rds describe-db-instances \
  --db-instance-identifier prowler-postgres \
  --query 'DBInstances[0].BackupRetentionPeriod' \
  --region us-east-1
```

### Cross-Region Replication

Create cross-region read replica:
```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier prowler-postgres-dr-replica \
  --source-db-instance-identifier arn:aws:rds:us-east-1:123456789012:db:prowler-postgres \
  --region us-west-2
```

### Failover Testing

Trigger Multi-AZ failover:
```bash
aws rds reboot-db-instance \
  --db-instance-identifier prowler-postgres \
  --force-failover \
  --region us-east-1
```

**Expected downtime**: 60-120 seconds.

## Maintenance

### Apply Updates

RDS automatically applies minor version updates during maintenance window.

Force immediate update:
```bash
aws rds modify-db-instance \
  --db-instance-identifier prowler-postgres \
  --engine-version 16.4 \
  --apply-immediately \
  --region us-east-1
```

### Parameter Changes

Non-dynamic parameters require reboot:
```bash
terraform apply  # Updates parameter group
aws rds reboot-db-instance \
  --db-instance-identifier prowler-postgres \
  --region us-east-1
```

## Security Best Practices

1. **Network Isolation**:
   - RDS in private subnets only
   - Security group allows only VPC CIDR
   - No public accessibility

2. **Encryption**:
   ```hcl
   rds_storage_encrypted = true  # At rest
   ```
   SSL/TLS for in-transit encryption (PostgreSQL default)

3. **IAM Authentication**:
   ```hcl
   iam_database_authentication_enabled = true
   ```

4. **Secrets Management**:
   Consider AWS Secrets Manager instead of Kubernetes secrets

5. **Least Privilege**:
   Create application-specific database user with limited permissions

6. **Auditing**:
   Enable CloudWatch Logs exports for postgresql logs

## Cost Optimization

1. **Right-sizing**: Start with smaller instance, scale up as needed
2. **Reserved Instances**: 1-year or 3-year commitments for 30-60% savings
3. **Storage Autoscaling**: Set `max_allocated_storage` to avoid over-provisioning
4. **Disable Multi-AZ for dev**: Save ~50% on non-production environments
5. **Snapshot Management**: Delete old manual snapshots
6. **Performance Insights**: Consider disabling for dev (small cost)

## Troubleshooting

### RDS Instance Won't Start

Check events:
```bash
aws rds describe-events \
  --source-identifier prowler-postgres \
  --source-type db-instance \
  --region us-east-1
```

### Connection Refused

Verify security group:
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_security_group_id) \
  --region us-east-1
```

Check if pods can reach RDS:
```bash
kubectl run -it --rm debug --image=postgres:16 --restart=Never -n prowler -- \
  psql -h <RDS_ENDPOINT> -U prowler_admin -d prowler_db
```

### High CPU Usage

Check slow queries in Performance Insights or:
```sql
SELECT pid, usename, query, state
FROM pg_stat_activity
WHERE state = 'active' AND query NOT ILIKE '%pg_stat_activity%'
ORDER BY query_start DESC;
```

### Storage Full

Increase allocation or enable autoscaling:
```hcl
rds_max_allocated_storage = 1000  # GB
```

## Cleanup

### Backup Before Deletion

```bash
aws rds create-db-snapshot \
  --db-instance-identifier prowler-postgres \
  --db-snapshot-identifier prowler-final-backup-$(date +%Y%m%d) \
  --region us-east-1
```

### Destroy Resources

```bash
# Disable deletion protection first
terraform apply -var="rds_deletion_protection=false"

# Then destroy
terraform destroy
```

**⚠️ Warning**: This deletes the RDS instance. Final snapshot is taken automatically.

## Production Checklist

- [ ] Multi-AZ enabled
- [ ] Encryption at rest enabled
- [ ] Deletion protection enabled
- [ ] Backup retention ≥ 7 days
- [ ] Performance Insights enabled
- [ ] Enhanced Monitoring enabled (60s interval)
- [ ] CloudWatch alarms configured
- [ ] Security group follows least privilege
- [ ] Parameter group optimized for workload
- [ ] Maintenance window configured
- [ ] Tags applied for cost allocation
- [ ] Disaster recovery plan documented
- [ ] Monitoring and alerting configured

## Next Steps

- Configure AWS Backup for centralized backup management
- Set up cross-region disaster recovery
- Implement database monitoring dashboard
- Configure CloudWatch alarms for critical metrics
- Set up read replicas for read scaling
- Implement connection pooling (RDS Proxy or PgBouncer)
- Configure automatic failover testing

## Support

For issues and questions:
- GitHub Issues: https://github.com/prowler-cloud/prowler-helm-chart/issues
- AWS RDS Documentation: https://docs.aws.amazon.com/rds/
- Prowler Documentation: https://docs.prowler.com
