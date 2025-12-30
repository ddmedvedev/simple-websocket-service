data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-279124164275"
    key    = "network/terraform.tfstate"
    region = var.region
  }
}

# Route53 zone for domain
data "aws_route53_zone" "main" {
  name         = local.domain
  private_zone = false
}
