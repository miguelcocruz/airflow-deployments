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
  vpc_id            = aws_vpc.this.id
  cidr_block        = "172.32.0.0/20"
  availability_zone = "us-east-2a"
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "172.32.160.0/20"
  availability_zone = "us-east-2b"
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
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# nat gateway (for the private subnet)
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_eip" "this" {
}

# subnet (private)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "172.32.80.0/20"
  availability_zone = "us-east-2a"
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
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.public.id
}


# security group

# cluster
resource "aws_ecs_cluster" "this" {
  name = "fargate-cluster"
}

# task definition (family, requires, cpu, memory, container definition(image, name, command, entrypoint, essential, portmappings))
resource "aws_ecs_task_definition" "this" {
  family       = "fargate-sample"
  network_mode = "awsvpc"
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
    command    = ["/bin/sh -c \"echo 'How you doin?' > /usr/local/apache2/htdocs/index.html && httpd-foreground\""]
  }])
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
}

resource "aws_security_group" "private" {
  vpc_id = aws_vpc.this.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# service (name, launch_type, desired_count, network configuration(subnets, security groups, assign public ip))
resource "aws_ecs_service" "this" {
  name            = "fargate-service"
  cluster         = aws_ecs_cluster.this.id
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.this.id
  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.private.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "fargate-app"
    container_port   = 80
  }
}

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

# load balancer
resource "aws_lb" "this" {
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.lb.id]
}

# listener
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: not found"
      status_code  = 404
    }
  }
}

# listener rules
resource "aws_lb_listener_rule" "this" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 100
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

# target group
resource "aws_lb_target_group" "this" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  # Error: creating ECS Service (fargate-service): InvalidParameterException: 
  # The provided target group arn:aws:elasticloadbalancing(...) 
  # has target type instance, which is incompatible with the awsvpc network mode specified in the task definition.
  target_type = "ip"

  #Error: creating ECS Service (fargate-service): InvalidParameterException: The target group with targetGroupArn arn:aws:elasticloadbalancing:us-east-2:204420314953:targetgroup/tf-20230128124711977800000001/456958974fbe25ab does not have an associated load balancer.
  depends_on = [aws_lb.this]

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# lb -> subnet
# listener -> lb
# listener rule -> listener
# listener rule -> target group
# auto scaling group -> target group