resource "aws_ecr_repository" "main" {
  name                 = "managed-target"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "keep last 10 images"
        action       = {
          type = "expire"
        }
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
      }
    ]
  })
}

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "ecs-cluster"

}

resource "aws_iam_role" "fargate_execution_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF
}

# Create IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "fargate_execution_role" {
  role       = aws_iam_role.fargate_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "fargate_ecs_managed_target" {
  name              = "/fargate/service/managed-target"
  retention_in_days = 3
}

resource "aws_ecs_task_definition" "managed_target_task_def" {
  network_mode             = "awsvpc"
  family                   = "managed-target"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.fargate_execution_role.arn
  cpu                      = 256
  memory                   = 512
  container_definitions    = jsonencode([
    {
      name        = "managed-target"
      image       = "${aws_ecr_repository.main.repository_url}:latest"
      essential   = true
      environment = [
        {
          name : "ECS_ENABLE_CONTAINER_METADATA"
          value : "true"
        }
      ]
      portMappings = [
        {
          containerPort = 2222
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.fargate_ecs_managed_target.name
          awslogs-stream-prefix = "ecs"
          awslogs-region        = var.aws_region
        }
      }

    }
  ])
}

resource "aws_ecs_cluster_capacity_providers" "capacity_provider" {
  cluster_name       = aws_ecs_cluster.ecs-cluster.name
  capacity_providers = ["FARGATE"]
}

resource "aws_security_group" "managed-target-container-sg" {
  ingress {
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  vpc_id = aws_vpc.vpc.id
}

resource "aws_ecs_service" "managed-target" {
  name                    = "managed_target"
  cluster                 = aws_ecs_cluster.ecs-cluster.id
  task_definition         = aws_ecs_task_definition.managed_target_task_def.arn
  launch_type             = "FARGATE"
  enable_ecs_managed_tags = true
  desired_count           = var.worker_count
  network_configuration {
    subnets         = [for s in aws_subnet.private : s.id]
    security_groups = [aws_security_group.managed-target-container-sg.id]

  }

  load_balancer {
    target_group_arn = aws_lb_target_group.managed-target-tg.arn
    container_name   = "managed-target"
    container_port   = 2222
  }

}


resource "aws_lb" "managed-target-lb" {
  name                       = "managed-target-lb"
  internal                   = false
  load_balancer_type         = "network"
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  security_groups            = [aws_security_group.managed-target-lb-sg.id]
  enable_deletion_protection = false
}


resource "aws_lb_target_group" "managed-target-tg" {
  name        = "managed-target-tg"
  target_type = "ip"
  port        = 2222
  protocol    = "TCP"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group" "managed-target-lb-sg" {
  ingress {
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  vpc_id = aws_vpc.vpc.id
}


resource "aws_lb_listener" "managed-target-listener" {
  load_balancer_arn = aws_lb.managed-target-lb.arn
  port              = 2222
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.managed-target-tg.arn
  }
}
