resource "local_file" "this" {
  content = tls_private_key.this.private_key_pem
  filename = "ec2-ssh-private-key.pem"
  file_permission = "0400"
}

output "public_ec2_public_ip" {
  value = aws_instance.public.public_ip
}

output "private_ec2_private_ip" {
  value = aws_instance.private.private_ip
}