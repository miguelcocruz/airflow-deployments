# ec2 instance (airflow scheduler, webserver)
# amazon rds (metastore)

provider "aws" {
  region = "us-east-2"
}

# iam role to allow ec2 instance to access s3
# iam policy (assume role policy)
data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# iam policy (s3 policy)
data "aws_iam_policy_document" "s3" {
  statement {
    effect = "Allow"
    actions = ["s3:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "s3" {
  policy = data.aws_iam_policy_document.s3.json
}

# iam role
resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# iam role policy attachment
resource "aws_iam_role_policy_attachment" "this" {
  role = aws_iam_role.this.id
  policy_arn = aws_iam_policy.s3.arn
}

# iam instance profile
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.id
}


# tls private key
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits = 4096
}

# aws key pair
resource "aws_key_pair" "this" {
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_file" "this" {
  filename = "private-key.pem"
  content = tls_private_key.this.private_key_openssh
  file_permission = "0400"
}

# security group (my ip ingress, all egress to ec2 instance)
resource "aws_security_group" "airflow" {
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.whitelisted_ip_address]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ec2 instance (ami, instance type, user_data, security_group, iam instance profile)
resource "aws_instance" "airflow" {
  ami = "ami-0ab0629dba5ae551d"
  instance_type = "t2.large"

  vpc_security_group_ids = [aws_security_group.airflow.id]
  key_name = aws_key_pair.this.key_name

  iam_instance_profile = aws_iam_instance_profile.this.id

  user_data_replace_on_change = true
  user_data = <<-EOT
    #!/bin/bash
    sudo apt-get update
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

    sudo apt-get update

    sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

    git clone https://github.com/miguelcocruz/airflow-deployments.git

    cd airflow-deployments/dep02/containers/airflow

    echo "METASTORE_CONN=postgres://${var.db_user}:${var.db_pwd}@${aws_db_instance.this.endpoint}/metastore" > .env
    
    sudo docker compose --env-file .env up

  EOT

  depends_on = [aws_db_instance.this]
}

resource "aws_s3_bucket" "this" {
  bucket = "mglvlm-20230121"
  force_destroy = true
}

resource "aws_db_instance" "this" {
  allocated_storage      = 10
  db_name                = "metastore"
  engine                 = "postgres"
  engine_version         = "13.6"
  instance_class         = "db.t3.medium"
  username               = var.db_user
  password               = var.db_pwd
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.db.id]
}

resource "aws_security_group" "db" {
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.whitelisted_ip_address]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    security_groups = [aws_security_group.airflow.id]
  }
}