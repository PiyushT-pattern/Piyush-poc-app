

####-------------VPC 

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a" # Change as needed
  tags = {
    Name = "my-subnet-1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b" # Change as needed
  tags = {
    Name = "my-subnet-2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-gateway"
  }
}

resource "aws_route_table" "subnet1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.subnet1.id
}


resource "aws_route_table" "subnet2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.subnet2.id
}


####------------------SECURITY GROUP

resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-security-group"
  }
}

####---------------------LOAD BALANCER

resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = [aws_subnet.subnet1.id,aws_subnet.subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "app-load-balancer"
  }
}

resource "aws_lb_target_group" "target_group" {
  name     = "nginx-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold  = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

####----------------ECS CLUSTER

resource "aws_ecs_cluster" "cluster" {
  name = "nginx-cluster"
}


####-----------------TASK DEFINATION

resource "aws_ecs_task_definition" "nginx" {
  family                   = "nginx"
  network_mode             = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name  = "nginx"
    image = "nginx:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

####-------------------ECS SERVICE

resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.subnet1.id, aws_subnet.subnet1.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "nginx"
    container_port   = 80
  }
}
