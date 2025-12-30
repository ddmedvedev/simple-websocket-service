locals {
  account_id     = data.aws_caller_identity.current.account_id
  ecr_image      = "${data.terraform_remote_state.ecr.outputs.repository_url}:${var.image_tag}"
  log_group_name = "/ecs/${var.service_name}"
}
