

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-rds-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_rds_policy" {
  name        = "ec2-rds-policy"
  description = "Policy for EC2 to access PostgreSQL and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = aws_secretsmanager_secret.postgresql_secret.arn
      },
      {
        Effect   = "Allow",
        Action   = ["rds:*"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_rds_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_rds_policy.arn
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow SSH and Grafana access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH access (restrict to your IP in production)
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Grafana access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Create SSH Key Pair From local 
resource "aws_key_pair" "ec2_key" {
  key_name   = "my-ec2-key"
  public_key = file("~/.ssh/id_rsa.pub") 
}

# EC2 Instance to run Grafana and Shell Script
resource "aws_instance" "grafana_instance" {
  ami                         = "ami-01816d07b1128cd2d" # Amazon Linux 2 AMI
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.ec2_sg.name]
  iam_instance_profile        = aws_iam_instance_profile.ec2_role.name
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_key.key_name
  user_data                   = <<-EOT
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable grafana
    yum install -y grafana jq
    systemctl enable --now grafana-server

    # Setup script to run every 10 minutes
    echo "*/10 * * * * root /home/ec2-user/sql.sh" >> /etc/crontab
  EOT

  tags = {
    Name = "GrafanaInstance"
  }
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_role" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}
