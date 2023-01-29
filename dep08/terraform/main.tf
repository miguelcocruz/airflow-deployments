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

# route table for public subnets (all traffic -> internet gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

# public subnet a
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "172.32.0.0/20"
  availability_zone = "us-east-2a"
}

# route table association (public subnet a -> route table for public subnets)
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# elastic ip for nat gateway
resource "aws_eip" "this" {

}

# nat gateway for private subnet
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public_a.id
}

# public subnet b
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "172.32.80.0/20"
  availability_zone = "us-east-2b"
}

# route table association (public subnet b -> route table for public subnets)
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# route table for private subnet (all traffic -> nat gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this.id
  }
}
# private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "172.32.160.0/20"
}

# route table association (private subnet -> route table for private subnet)
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}





# load balancer (public subnet, security group)
resource "aws_lb" "this" {
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups = [aws_security_group.lb.id]
}

# listener (port, protocol, default_action)
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port     = 80 #TODO
  protocol = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: not found"
      status_code  = 404
    }
  }
}

# listener rule (listener, condition, action(target_group))
resource "aws_lb_listener_rule" "this" {
  listener_arn = aws_lb_listener.this.arn
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# target group (port, protocol, private subnet)
resource "aws_lb_target_group" "this" {
  vpc_id      = aws_vpc.this.id
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  depends_on  = [aws_lb.this]
}

# load balancer security group (all ingress from whitelisted ip, allow all egress)
resource "aws_security_group" "lb" {
  vpc_id = aws_vpc.this.id
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

# ecs cluster (name)
resource "aws_ecs_cluster" "this" {
  name = "fargate-cluster"
}

# ecs task definition (family, requires_compatibility, network_mode, cpu, memory, container_definitions(name, image, port mappings, essential, command, entrypoint))
# 2 container definitions
resource "aws_ecs_task_definition" "this" {
  family                 = "fargate-sample"
  network_mode           = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                    = 256
  memory                 = 512
  container_definitions = jsonencode([
    {
      name  = "app1"
      image = "public.ecr.aws/docker/library/httpd:latest"
      portMappings = [{
        hostPort      = 80
        containerPort = 80
        protocol      = "tcp"
      }]
      essential  = true
      entrypoint = ["sh", "-c"]
      command    = ["/bin/sh -c \"echo 'How you doin?' > /usr/local/apache2/htdocs/index.html && httpd-foreground \""]
    }
  ])
}
# ecs service (name, launch_type, network_configuration(subnets, security groups), load_balancer(target_group, port name, container name))
resource "aws_ecs_service" "this" {
  name        = "fargate-service"
  cluster = aws_ecs_cluster.this.id
  launch_type = "FARGATE"
  desired_count = 1
  task_definition = aws_ecs_task_definition.this.id
  network_configuration {
    subnets         = [aws_subnet.private.id]
    security_groups = [aws_security_group.ecs_service.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app1"
    container_port   = 80
  }
}

# ecs service security group (allow ingress from load balance security group)
resource "aws_security_group" "ecs_service" {
  vpc_id = aws_vpc.this.id
  ingress {
    from_port      = 0
    to_port        = 0
    protocol       = "-1"
    security_groups = [aws_security_group.lb.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}