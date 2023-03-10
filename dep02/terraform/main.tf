# Provider
provider "aws" {
  region = "us-east-2"
}

# IAM Roles
# IAM Policy - Assume role policy
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Role
resource "aws_iam_role" "this" {
  name               = "CustomS3Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# IAM Policy
data "aws_iam_policy_document" "s3_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
}

# Role-policy
resource "aws_iam_role_policy" "this" {
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.s3_permissions.json
}

# IAM Role instance
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name
}

# Security Groups
# Key-pair generator
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS key-pair
resource "aws_key_pair" "this" {
  public_key = tls_private_key.this.public_key_openssh
}

# Security Group - EC2 Airflow
resource "aws_security_group" "airflow" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.whitelisted_ip_address]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.whitelisted_ip_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# EC2 Airflow
resource "aws_instance" "airflow" {
  ami           = "ami-0ff39345bd62c82a5"
  instance_type = "t2.large"

  key_name = aws_key_pair.this.key_name

  security_groups      = [aws_security_group.airflow.name]
  iam_instance_profile = aws_iam_instance_profile.this.name

  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    sudo apt-get -y update
    sudo apt-get -y install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get -y update

    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    sudo apt-get -y update

    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

    git clone https://github.com/miguelcocruz/airflow-deployments.git

    cd airflow-deployments/dep02/containers/airflow

    echo "METASTORE_CONN=postgresql://airflow:airflow@${aws_instance.metastore.private_dns}:5432/airflow" > .env

    sudo docker compose --env-file .env up -d

  EOT
}







# Security Group - EC2 metastore
resource "aws_security_group" "metastore" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.whitelisted_ip_address]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.airflow.id]
    
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# EC2 metastore
resource "aws_instance" "metastore" {
  ami           = "ami-0ff39345bd62c82a5"
  instance_type = "t2.large"

  # the same key is used to access both ec2
  # but each ec2 endpoint is different
  key_name = aws_key_pair.this.key_name

  security_groups      = [aws_security_group.metastore.name]
  iam_instance_profile = aws_iam_instance_profile.this.name

  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    sudo apt-get -y update
    sudo apt-get -y install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get -y update

    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    sudo apt-get -y update

    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

    git clone https://github.com/miguelcocruz/airflow-deployments.git

    cd airflow-deployments/dep02/containers/metastore

    sudo docker compose up -d

  EOT
}



# S3 bucket
resource "aws_s3_bucket" "this" {
  bucket        = "mglvlm-20230121"
  force_destroy = true
}