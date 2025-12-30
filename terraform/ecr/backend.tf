terraform {
  backend "s3" {
    bucket       = "terraform-state-279124164275"
    key          = "ecr/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

