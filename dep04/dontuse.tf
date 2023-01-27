provider "aws" {
  region = "us-east-2"
}

# vpc
resource "aws_vpc" "this" {
  cidr_block = "172.32.0.0/16"
}

# internet gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

# subnet (public)
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "172.32.0.0/20"
}

# route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

# route table association
resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

# aws eis (elastic id for the nat gateway)
resource "aws_eip" "this" {

}

# nat gateway (for the private subnet)
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.this]
}

# security group


# subnet (private)
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "172.32.80.0/20"
}

# route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this.id
  }
}

# route table association
resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private.id
}

# security group

# ecs cluster
resource "aws_ecs_cluster" "this" {
  name = "lgmcluster"
}

# ecs task definition
resource "aws_ecs_task_definition" "this" {
  family                   = "lgmtaskfamily"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 10
  memory                   = 1024

  container_definitions = jsonencode([{
    name  = "lgmcontainer"
    image = var.image
    essential = true
    portMappings = [{
        protocol = "tcp"
        containerPort = 8080
        hostPort = 8080
    }]
  }])
}

# ecs service

# load balancer

# iam role/policies