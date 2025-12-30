terraform {
  backend "s3" {
    bucket       = "terraform-state-279124164275"
    key          = "ecs-service/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
