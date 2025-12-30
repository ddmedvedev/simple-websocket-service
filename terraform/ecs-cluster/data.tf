data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-279124164275"
    key    = "network/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "terraform-state-279124164275"
    key    = "alb/terraform.tfstate"
    region = var.region
  }
}

