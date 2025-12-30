# Infrastructure

Terraform modules for deploying the WebSocket service on AWS.

## Components

| Module | Description |
|--------|-------------|
| `network/` | VPC, subnets, NAT Gateway, S3 VPC Endpoint |
| `ecr/` | Container registry |
| `alb/` | Application Load Balancer, SSL certificate |
| `ecs-cluster/` | ECS cluster, security groups |
| `ecs-service/` | ECS service, task definition, IAM roles, S3 bucket |

## Prerequisites

1. **Terraform**: Install Terraform on your machine. Visit the [Terraform downloads page](https://www.terraform.io/downloads.html) to get the latest version.

2. **AWS CLI v2**: Install and configure AWS CLI version 2. It is required for authentication and connections to AWS services including SSM. See the [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

3. **Domain in Route53**: A hosted zone for SSL certificate validation.

Verify installation:

```bash
terraform --version
# Terraform v1.x.x

aws --version
# aws-cli/2.x.x Python/3.x.x ...
```

## Configuration

### AWS CLI Configuration

Option 1 — credentials file `~/.aws/credentials`:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
region = us-east-1
```

Option 2 — environment variables:

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_DEFAULT_REGION="us-east-1"
```

### Verify Configuration

```bash
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

## Deployment Order

Modules depend on each other via remote state. Deploy in order:

```bash
# 1. Network
cd network
terraform init && terraform apply

# 2. ECR
cd ../ecr
terraform init && terraform apply

# 3. ALB
cd ../alb
terraform init && terraform apply

# 4. ECS Cluster
cd ../ecs-cluster
terraform init && terraform apply

# 5. ECS Service
cd ../ecs-service
terraform init && terraform apply
```

## Before First Deploy

1. Create S3 bucket for Terraform state with versioning:

```bash
aws s3api create-bucket --bucket terraform-state-$(aws sts get-caller-identity --query Account --output text) --region us-east-1

aws s3api put-bucket-versioning --bucket terraform-state-$(aws sts get-caller-identity --query Account --output text) --versioning-configuration Status=Enabled
```

2. Create SSM parameter for OpenAI API key:

```bash
aws ssm put-parameter \
  --name "/ecs/simple-websocket-service/OPENAI_API_KEY" \
  --type "SecureString" \
  --value "sk-your-openai-api-key"
```

## Remote State

Terraform state stored in S3 bucket `terraform-state-279124164275` with keys `<module>/terraform.tfstate`.

## Destroy Order

Reverse of deploy:

```bash
cd ecs-service && terraform destroy
cd ../ecs-cluster && terraform destroy
cd ../alb && terraform destroy
cd ../ecr && terraform destroy
cd ../network && terraform destroy
```
