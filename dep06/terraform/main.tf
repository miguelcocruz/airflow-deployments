provider "aws" {
  region = "us-east-2"
}

# 1. Create cluster
resource "aws_ecs_cluster" "this" {
  name = "fargate-cluster"
}

# 2. Register a task definition
resource "aws_ecs_task_definition" "this" {
  family       = "sample-fargate"
  network_mode = "awsvpc"
  container_definitions = jsonencode([{
    name  = "fargate-app"
    image = "public.ecr.aws/docker/library/httpd:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    essential  = true
    entrypoint = ["sh", "-c"]
    command    = ["/bin/sh -c \"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' >  /usr/local/apache2/htdocs/index.html && httpd-foreground\""]
  }])
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
}

# 3. Create a service
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


resource "aws_security_group" "this" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.whitelisted_ip_address]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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