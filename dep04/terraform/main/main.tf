provider "aws" {
  region = "us-east-2"
}

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