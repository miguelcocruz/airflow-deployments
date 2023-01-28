# 1. create cluster (name)
# 2. register a task definition (family, network_mode, cpu, memory, ["fargate"], container definitions (image, name, port mappings, command, entrypoint, essential))
# 3. create a service (cluster, task definition, desired count, network configuration(subnets, security groups, has public ip), ["fargate"])

provider "aws" {
  region = "us-east-2"
}

resource "aws_ecs_cluster" "this" {
  name = "fargate-cluster"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "sample-fargate"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode([{
    name  = "fargate-app"
    image = "public.ecr.aws/docker/library/httpd:latest"
    portMappings = [{
      hostPort      = 80
      containerPort = 80
      protocol      = "tcp"
    }]
    essential  = true
    entrypoint = ["sh", "-c"]
    command    = ["/bin/sh -c \"echo 'How you doin' > /usr/local/apache2/htdocs/index.html && httpd-foreground\""]
  }])
}

resource "aws_ecs_service" "this" {
  name            = "fargate-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.id
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "this" {
  ingress {
    from_port   = 80
    to_port     = 80
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