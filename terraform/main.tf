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
  availability_zone       = "eu-north-1c"
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
  availability_zone = "eu-north-1c"
  tags              = { Name = "private-subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-north-1b"
  tags              = { Name = "private-subnet-2" }
}

# ----------------------------
# NAT Gateway
# ----------------------------
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "nat-gateway" }
}

# ----------------------------
# Route Tables
# ----------------------------
# Public RT
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

# Private RT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "private-rt" }
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
  name        = "alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
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

  tags = { Name = "alb-sg" }
}

# ECS Tasks SG
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-task-sg"
  description = "ECS task security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  description     = "ALB to link-service"
  from_port       = 3000
  to_port         = 3000
  protocol        = "tcp"
  security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
  description     = "Analytics service from ALB"
  from_port       = 4000
  to_port         = 4000
  protocol        = "tcp"
  security_groups = [aws_security_group.alb_sg.id]
}



  # Container-to-container Communication
  ingress {
    description = "Internal ECS"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ecs-task-sg" }
}

# RDS SG
resource "aws_security_group" "rds_sg" {
  name        = "rds-postgres-sg"
  description = "Allow Postgres access from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-postgres-sg"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "rds-public-subnets"
  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
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

# Target Group
resource "aws_lb_target_group" "tg" {
  name        = "node-tg-ec2"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

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

# Link-Service Target Group
resource "aws_lb_target_group" "link_tg" {
  name        = "link-service-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

# Link-Service Listener Rule
resource "aws_lb_listener_rule" "link_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10  # Must be unique

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.link_tg.arn
  }

  condition {
    path_pattern {
      values = [
        "/api/shorten",
        "/api/links",
        "/api/links/*"
      ]
    }
  }
}

# Analytics Target Group
resource "aws_lb_target_group" "analytics_tg" {
  name        = "analytics-service-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/health"
  }
}

# Analytics Listener Rule
resource "aws_lb_listener_rule" "analytics_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20  # Must be unique and higher than link-rule

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.analytics_tg.arn
  }

  condition {
    path_pattern {
      values = [
        "/api/analytics",
        "/api/analytics/*"
      ]
    }
  }
}


# ----------------------------
# ECS EC2 Cluster
# ----------------------------
resource "aws_ecs_cluster" "main" {
  name = "node-ec2-cluster"
}

# ----------------------------
# IAM Roles
# ----------------------------
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_profile" {
  role = aws_iam_role.ecs_instance_role.name
}

# ECS Task Role (for secrets)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_secrets_policy" {
  name   = "ecs-task-secrets-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = ["arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret*"]
    }]
  })
}

# ECS Execution Role (for logs + pulling secrets)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_logs" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy" "ecs_execution_secrets_policy" {
  name   = "ecs-execution-secrets-policy"
  role   = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = ["arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret*"]
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecs_node" {
  name              = "/ecs/node-ec2-cluster"
  retention_in_days = 7
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

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "ecs" {
  image_id      = data.aws_ami.ecs.id
  instance_type = "m5.large"
  key_name      = "Lab-Key"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_profile.name
  }

  user_data = base64encode(<<-EOT
#!/bin/bash
echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
echo "ECS_LOGLEVEL=debug" >> /etc/ecs/ecs.config
echo "ECS_RESERVED_MEMORY=512" >> /etc/ecs/ecs.config
EOT
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_sg.id]
  }

}

resource "aws_autoscaling_group" "ecs" {
  name                      = "ecs-cluster-asg"
  max_size                  = 3
  min_size                  = 3
  desired_capacity          = 3
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  force_delete              = true
  tag{
      key                 = "Name"
      value               = "ecs-instance"
      propagate_at_launch = true
    }
}


# Cloud map
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "internal"
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "link_service" {
  name = "link-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }
}

# ----------------------------
# ECS Task Definition
# ----------------------------
resource "aws_ecs_task_definition" "link_service" {
  family                   = "link-service-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu    = "256"
  memory = "256"

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "link-service"
      image     = "docker.io/abdulwahab4d/url-shorten-final-project:link-service-ci-${var.link_service_tag}"
      essential = true
      portMappings = [{
        containerPort = 3000
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/node-ec2-cluster"
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "link-service"
        }
      }
      secrets = [ 
        {
          name      = "DB_HOST"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_HOST::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_NAME::"
        },
        {
          name      = "DB_USER"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_USER::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_PASSWORD::"
        }
       ]
    }
  ])
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu    = "512"
  memory = "512"

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "docker.io/abdulwahab4d/url-shorten-final-project:frontend-ci-${var.frontend_tag}"
      essential = true
      portMappings = [{
        containerPort = 80
      }]
      environment = [
        {
          name  = "LINK_SERVICE_URL"
          value = "http://${aws_lb.alb.dns_name}/api"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/node-ec2-cluster"
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "analytics" {
  family                   = "analytics-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu    = "256"
  memory = "256"

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "analytics"
      image     = "docker.io/abdulwahab4d/url-shorten-final-project:analytics-service-ci-${var.analytics_tag}"
      essential = true
      portMappings = [{
        containerPort = 4000
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/node-ec2-cluster"
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "analytics"
        }
      }
      secrets = [ 
        {
          name      = "DB_HOST"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_HOST::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_NAME::"
        },
        {
          name      = "DB_USER"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_USER::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:eu-north-1:828798301136:secret:urlshortener-db-secret-pGfNMn:DB_PASSWORD::"
        }
       ]
    }
  ])
}


# ----------------------------
# ECS Service
# ----------------------------
resource "aws_ecs_service" "link_service" {
  name            = "link-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.link_service.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.link_service.arn
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.link_tg.arn
    container_name   = "link-service"
    container_port   = 3000
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "frontend"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.http]
}
resource "aws_ecs_service" "analytics" {
  name            = "analytics-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.analytics.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.analytics_tg.arn
    container_name   = "analytics"
    container_port   = 4000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.analytics_rule
  ]
}

# ----------------------------
# Outputs
# ----------------------------
output "link_service_alb_url" {
  value = "http://${aws_lb.alb.dns_name}/api/shorten"
}

output "link_service_alb_url_link" {
  value = "http://${aws_lb.alb.dns_name}/api/links"
}

output "analytics_service_alb_url" {
  value = "http://${aws_lb.alb.dns_name}/api/analytics"
}