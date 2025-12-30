# CloudWatch Log Group for ECS tasks
resource "aws_cloudwatch_log_group" "main" {
  name              = local.log_group_name
  retention_in_days = 7

  tags = {
    Service = var.service_name
  }
}
