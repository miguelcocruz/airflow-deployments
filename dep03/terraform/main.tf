provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "this" {
  cidr_block = "172.32.0.0/16"
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}


# Public Subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "172.32.0.0/20"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # Note that the default route, mapping the VPC's CIDR block to "local"
  # is created implicitly and cannot be specified.

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}






# Public EC2 instance
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  public_key = tls_private_key.this.public_key_openssh
}

resource "aws_security_group" "public" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "public" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"

  subnet_id = aws_subnet.public.id

  key_name = aws_key_pair.this.key_name

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.public.id]

  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p 8080 &
  EOT
}






# Private Subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "172.32.80.0/20"
}


# Private EC2 instance
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


}

resource "aws_eip" "this" {

}

resource "aws_nat_gateway" "this" {
  connectivity_type = "public"
  subnet_id         = aws_subnet.public.id
  allocation_id     = aws_eip.this.id

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_instance" "private" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"

  subnet_id = aws_subnet.private.id

  associate_public_ip_address = true

  key_name = aws_key_pair.this.key_name

  vpc_security_group_ids = [aws_security_group.private.id]

  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    echo "Hello, World. You're on the private." > index.html
    nohup busybox httpd -f -p 8080 &
    
    git clone https://github.com/miguelcocruz/airflow-deployments.git
  EOT
}