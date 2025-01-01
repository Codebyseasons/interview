# Create a PostgreSQL RDS database cluster
resource "aws_rds_cluster" "postgresql_cluster" {
  cluster_identifier      = "postgresql-cluster"
  engine                  = "aurora-postgresql"  
  master_username         = "sumanth"
  master_password         = "sumanthdata123"  
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  engine_version          = "16.3"  # Adjust as per the latest version
  db_subnet_group_name    = aws_db_subnet_group.default_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.postgresql_sg.id]
}

resource "aws_rds_cluster_instance" "postgresql_instance" {
  count               = 1  
  identifier          = "postgresql-instance-${count.index}"
  cluster_identifier  = aws_rds_cluster.postgresql_cluster.id
  instance_class      = "db.r5.large"
  publicly_accessible = false
  engine              = "aurora-postgresql"  # Use the Aurora PostgreSQL engine
}

# Subnet Group for PostgreSQL
resource "aws_db_subnet_group" "default_subnet_group" {
  name       = "default-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

# Data Source for Default Subnets
data "aws_subnets" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Default VPC Data Source
data "aws_vpc" "default" {
  default = true
}

# Security Group for PostgreSQL
resource "aws_security_group" "postgresql_sg" {
  name        = "postgresql-security-group"
  description = "Allow access to PostgreSQL"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Secrets Manager to store database credentials
resource "aws_secretsmanager_secret" "postgresql_secret" {
  name        = "postgresql-db-credentials"
  description = "Credentials for the PostgreSQL database"
}

resource "aws_secretsmanager_secret_version" "postgresql_secret_version" {
  secret_id = aws_secretsmanager_secret.postgresql_secret.id
  secret_string = jsonencode({
    username = "sumanth",
    password = "sumanthdata123"
  })
}