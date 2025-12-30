# Target Group for the service
resource "aws_lb_target_group" "main" {
  name        = var.service_name
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Required for WebSocket support
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Service = var.service_name
  }
}

# ALB Listener Rule
resource "aws_lb_listener_rule" "main" {
  listener_arn = data.terraform_remote_state.alb.outputs.alb_https_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = {
    Service = var.service_name
  }
}
