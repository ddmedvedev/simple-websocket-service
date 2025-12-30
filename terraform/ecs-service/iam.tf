# IAM role for ECS task execution (pulling images, injecting secrets, CloudWatch logs)
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.service_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution_base" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM access for execution role (to inject secrets into containers)
data "aws_iam_policy_document" "execution_ssm" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      data.aws_ssm_parameter.openai_api_key.arn
    ]
  }
}

resource "aws_iam_role_policy" "execution_ssm" {
  name   = "${var.service_name}-execution-ssm"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_ssm.json
}

# IAM role for ECS task (for application to access AWS resources)
resource "aws_iam_role" "task" {
  name               = "${var.service_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

# SSM permissions for ECS Exec
data "aws_iam_policy_document" "task_ssm" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_ssm" {
  name   = "${var.service_name}-task-ssm"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_ssm.json
}

# S3 permissions for task role
data "aws_iam_policy_document" "task_s3" {
  statement {
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.audio.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name   = "${var.service_name}-task-s3"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_s3.json
}
