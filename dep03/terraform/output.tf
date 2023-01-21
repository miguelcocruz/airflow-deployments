resource "local_file" "this" {
  content         = tls_private_key.this.private_key_pem
  filename        = "ec2-ssh-private-key.pem"
  file_permission = "0400"
}

output "ec2_airflow_public_dns_name" {
  value = aws_instance.airflow.public_dns
}

output "ec2_metastore_public_dns_name" {
  value = aws_instance.metastore.public_dns
}
