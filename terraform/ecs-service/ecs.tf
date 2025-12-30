# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = local.ecr_image

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "S3_BUCKET"
          value = aws_s3_bucket.audio.id
        }
      ]

      secrets = [
        {
          name      = "OPENAI_API_KEY"
          valueFrom = data.aws_ssm_parameter.openai_api_key.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Service = var.service_name
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name                   = var.service_name
  cluster                = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_id
  task_definition        = aws_ecs_task_definition.main.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = data.terraform_remote_state.network.outputs.private_subnets
    security_groups  = [data.terraform_remote_state.ecs_cluster.outputs.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener_rule.main
  ]

  tags = {
    Service = var.service_name
  }
}
