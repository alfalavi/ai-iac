data "aws_region" "current" {}

locals {
  common_tags = {
    environment = var.environment
    service     = "todo-service"
    managed_by  = "terraform"
    pe-lab      = "true"
  }
  service_name = "${var.environment}-todo-service"
  name_suffix  = random_string.resource_suffix.result
}

resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "todo_service" {
  count                = var.create_networking ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-vpc-${local.name_suffix}"
  })
}

resource "aws_internet_gateway" "todo_service" {
  count  = var.create_networking ? 1 : 0
  vpc_id = aws_vpc.todo_service[0].id

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-igw-${local.name_suffix}"
  })
}

resource "aws_subnet" "public" {
  count                   = var.create_networking ? var.subnet_count : 0
  vpc_id                  = aws_vpc.todo_service[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-public-${count.index + 1}-${local.name_suffix}"
  })
}

resource "aws_subnet" "private" {
  count             = var.create_networking ? var.subnet_count : 0
  vpc_id            = aws_vpc.todo_service[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, var.subnet_count + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-private-${count.index + 1}-${local.name_suffix}"
  })
}

resource "aws_eip" "nat" {
  count  = var.create_networking ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-nat-eip-${local.name_suffix}"
  })
}

resource "aws_nat_gateway" "todo_service" {
  count         = var.create_networking ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-nat-${local.name_suffix}"
  })

  depends_on = [aws_internet_gateway.todo_service]
}

resource "aws_route_table" "public" {
  count  = var.create_networking ? 1 : 0
  vpc_id = aws_vpc.todo_service[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.todo_service[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-public-rt-${local.name_suffix}"
  })
}

resource "aws_route_table" "private" {
  count  = var.create_networking ? 1 : 0
  vpc_id = aws_vpc.todo_service[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.todo_service[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.service_name}-private-rt-${local.name_suffix}"
  })
}

resource "aws_route_table_association" "public" {
  count          = var.create_networking ? var.subnet_count : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = var.create_networking ? var.subnet_count : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

locals {
  effective_vpc_id             = var.create_networking ? aws_vpc.todo_service[0].id : var.vpc_id
  effective_public_subnet_ids  = var.create_networking ? aws_subnet.public[*].id : var.public_subnet_ids
  effective_private_subnet_ids = var.create_networking ? aws_subnet.private[*].id : var.private_subnet_ids
  effective_backend_image      = length(trimspace(var.backend_image)) > 0 ? var.backend_image : "${aws_ecr_repository.backend.repository_url}:latest"
  effective_frontend_image     = length(trimspace(var.frontend_image)) > 0 ? var.frontend_image : "${aws_ecr_repository.frontend.repository_url}:latest"
}

resource "aws_ecr_repository" "backend" {
  name                 = "${local.service_name}-backend-${local.name_suffix}"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${local.service_name}-frontend-${local.name_suffix}"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the 10 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the 10 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${local.service_name}/${local.name_suffix}/frontend"
  retention_in_days = var.log_retention_in_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.service_name}/${local.name_suffix}/backend"
  retention_in_days = var.log_retention_in_days
  tags              = local.common_tags
}

resource "aws_ecs_cluster" "todo_service" {
  name = "${local.service_name}-${local.name_suffix}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.service_name}-execution-role-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.service_name}-task-role-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags               = local.common_tags
}

resource "aws_security_group" "alb" {
  name        = "${local.service_name}-alb-sg-${local.name_suffix}"
  description = "Allow public HTTP to ALB"
  vpc_id      = local.effective_vpc_id

  ingress {
    description = "Allow inbound HTTP from internet"
    from_port   = var.frontend_container_port
    to_port     = var.frontend_container_port
    protocol    = "tcp"
    cidr_blocks = [var.alb_ingress_cidr]
  }

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow outbound TCP to ECS task targets"
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.service_name}-ecs-sg-${local.name_suffix}"
  description = "Allow HTTP from ALB only"
  vpc_id      = local.effective_vpc_id

  ingress {
    description     = "Allow frontend traffic from ALB"
    from_port       = var.frontend_container_port
    to_port         = var.frontend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound HTTPS for image pulls and APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound DNS over UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound DNS over TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_lb" "todo_service" {
  #checkov:skip=CKV_AWS_91: Access logs bucket is not managed in this lab module.
  name                       = substr("${local.service_name}-alb-${local.name_suffix}", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = local.effective_public_subnet_ids
  enable_deletion_protection = var.alb_deletion_protection_enabled
  drop_invalid_header_fields = true

  tags = local.common_tags
}

resource "aws_lb_target_group" "todo_service" {
  name        = substr("${local.service_name}-tg-${local.name_suffix}", 0, 32)
  port        = var.frontend_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.effective_vpc_id

  health_check {
    enabled             = true
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2: Lab service intentionally uses HTTP-only listener; TLS termination is out of scope.
  load_balancer_arn = aws_lb.todo_service.arn
  port              = var.frontend_container_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.todo_service.arn
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "todo_service" {
  family                   = "${local.service_name}-${local.name_suffix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = local.effective_backend_image
      essential = true
      portMappings = [
        {
          containerPort = var.backend_container_port
          hostPort      = var.backend_container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "frontend"
      image     = local.effective_frontend_image
      essential = true
      portMappings = [
        {
          containerPort = var.frontend_container_port
          hostPort      = var.frontend_container_port
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "backend"
          condition     = "START"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "todo_service" {
  name                              = "${local.service_name}-${local.name_suffix}"
  cluster                           = aws_ecs_cluster.todo_service.id
  task_definition                   = aws_ecs_task_definition.todo_service.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = local.effective_private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.todo_service.arn
    container_name   = "frontend"
    container_port   = var.frontend_container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
}
