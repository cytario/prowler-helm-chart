# Generate random password if not provided
resource "random_password" "rds_master" {
  count   = var.rds_master_password == "" ? 1 : 0
  length  = 32
  special = true
}

locals {
  rds_password = var.rds_master_password != "" ? var.rds_master_password : random_password.rds_master[0].result
}

# RDS Subnet Group
resource "aws_db_subnet_group" "prowler" {
  name       = "${var.release_name}-rds-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.release_name}-rds-subnet-group"
  })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.release_name}-rds-sg"
  description = "Security group for Prowler RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.release_name}-rds-sg"
  })
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "prowler" {
  identifier     = "${var.release_name}-postgres"
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  # Storage
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.rds_storage_encrypted

  # Database
  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = local.rds_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.prowler.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 5432

  # High Availability
  multi_az = var.rds_multi_az

  # Backup
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.release_name}-postgres-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  # Protection
  deletion_protection = var.rds_deletion_protection

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = var.rds_performance_insights_enabled
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Parameters
  parameter_group_name = aws_db_parameter_group.prowler.name

  tags = merge(var.tags, {
    Name = "${var.release_name}-postgres"
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "prowler" {
  name   = "${var.release_name}-postgres-params"
  family = "postgres16"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(var.tags, {
    Name = "${var.release_name}-postgres-params"
  })
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.release_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Create namespace
resource "kubernetes_namespace" "prowler" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "prowler"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Create Kubernetes secret with RDS credentials
resource "kubernetes_secret" "rds" {
  metadata {
    name      = "prowler-rds-postgres"
    namespace = var.namespace
  }

  data = {
    POSTGRES_HOST           = aws_db_instance.prowler.address
    POSTGRES_PORT           = tostring(aws_db_instance.prowler.port)
    POSTGRES_ADMIN_USER     = var.rds_master_username
    POSTGRES_ADMIN_PASSWORD = local.rds_password
    POSTGRES_USER           = var.rds_master_username
    POSTGRES_PASSWORD       = local.rds_password
    POSTGRES_DB             = var.rds_database_name
  }

  depends_on = [
    kubernetes_namespace.prowler,
    aws_db_instance.prowler
  ]
}

# Deploy Prowler Helm Chart with AWS RDS
resource "helm_release" "prowler" {
  name             = var.release_name
  chart            = var.chart_path != "" ? var.chart_path : "prowler"
  repository       = var.chart_path != "" ? null : var.chart_repository
  version          = var.chart_path != "" ? null : var.chart_version
  namespace        = var.namespace
  create_namespace = false
  wait             = true
  timeout          = 600

  depends_on = [
    kubernetes_namespace.prowler,
    aws_db_instance.prowler,
    kubernetes_secret.rds
  ]

  # Disable internal PostgreSQL
  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  # Configure external RDS secret for API
  set {
    name  = "api.secrets[0]"
    value = kubernetes_secret.rds.metadata[0].name
  }

  # Configure external RDS secret for Worker
  set {
    name  = "worker.secrets[0]"
    value = kubernetes_secret.rds.metadata[0].name
  }

  # Configure external RDS secret for Worker Beat
  set {
    name  = "worker_beat.secrets[0]"
    value = kubernetes_secret.rds.metadata[0].name
  }

  # Valkey Configuration
  set {
    name  = "valkey.enabled"
    value = "true"
  }

  set {
    name  = "valkey.dataStorage.enabled"
    value = "false"
  }

  # API Configuration
  set {
    name  = "api.replicaCount"
    value = var.api_replicas
  }

  # UI Configuration
  set {
    name  = "ui.replicaCount"
    value = var.ui_replicas
  }

  # Worker Configuration
  set {
    name  = "worker.replicaCount"
    value = var.worker_replicas
  }
}
