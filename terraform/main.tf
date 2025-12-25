# ----------------------------
# VPC
# ----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

# ----------------------------
# Internet Gateway
# ----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

# ----------------------------
# Public Subnets
# ----------------------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-2" }
}

# ----------------------------
# Private Subnets
# ----------------------------
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-north-1a"
  tags              = { Name = "private-subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-north-1b"
  tags              = { Name = "private-subnet-2" }
}

# ----------------------------
# Route Tables
# ----------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ----------------------------
# NAT Gateway (for private subnets)
# ----------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "nat-gateway" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ----------------------------
# Security Groups
# ----------------------------
# ALB SG
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
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
}

# ECS Tasks SG
resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------
# ALB
# ----------------------------
resource "aws_lb" "alb" {
  name               = "node-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  enable_deletion_protection = false
}

# Target Group for awsvpc (use "ip" target type!)
resource "aws_lb_target_group" "tg" {
  name        = "node-tg-ec2-awsvpc"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"   # ✅ important for awsvpc tasks

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ----------------------------
# ECS Cluster
# ----------------------------
resource "aws_ecs_cluster" "main" {
  name = "node-ec2-cluster-awsvpc"
}

# ----------------------------
# EC2 IAM Role
# ----------------------------
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [ { Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" } ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_profile" {
  role = aws_iam_role.ecs_instance_role.name
}

# ----------------------------
# ECS EC2 Instances (Launch Template + ASG)
# ----------------------------
data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "ecs" {
  image_id      = data.aws_ami.ecs.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_profile.name
  }

  user_data = base64encode(<<-EOT
#!/bin/bash
echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
EOT
  )

  network_interfaces {
    security_groups = [aws_security_group.ecs_sg.id]
  }
}

resource "aws_autoscaling_group" "ecs" {
  desired_capacity     = 1
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
}

# ----------------------------
# ECS Task Definition (awsvpc)
# ----------------------------
resource "aws_ecs_task_definition" "node" {
  family                   = "node-task-ec2-awsvpc"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"  # ✅ changed from bridge
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "node-app"
    image     = "docker.io/abdulwahab4d/url-shorten-final-project:frontend-latest"
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
  }])
}

# ----------------------------
# ECS Service (awsvpc)
# ----------------------------
resource "aws_ecs_service" "node" {
  name            = "node-service-ec2-awsvpc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.node.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {   # ✅ required for awsvpc
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "node-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}
