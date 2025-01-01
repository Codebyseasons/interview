# Output the Grafana URL
output "grafana_url" {
  value = "http://${aws_instance.grafana_instance.public_ip}:3000"
}

# Output the EC2 Instance Public IP
output "ec2_public_ip" {
  value = aws_instance.grafana_instance.public_ip
}


# Output the RDS endpoint
output "db_instance_endpoint" {
  value = aws_rds_cluster.postgresql_cluster.endpoint
}
