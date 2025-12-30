# Simple WebSocket Audio Transcription Service

Real-time audio transcription service using WebSocket streaming and OpenAI Whisper API.

## Architecture

```
Client → ALB (HTTPS/WSS) → ECS Fargate → OpenAI Whisper API
                              ↓
                           S3 (audio storage)
```

## Project Structure

```
.
├── app/                    # Application (see app/README.md)
├── terraform/              # Infrastructure (see terraform/README.md)
└── .github/workflows/      # CI/CD
```

## Documentation

| Part | Description | README |
|------|-------------|--------|
| **Application** | WebSocket server, Docker, local development | [app/README.md](app/README.md) |
| **Infrastructure** | Terraform modules, AWS deployment | [terraform/README.md](terraform/README.md) |
| **CI/CD** | GitHub Actions workflow | [.github/WORKFLOW.md](.github/WORKFLOW.md) |

## Quick Start

### Local Development

```bash
cd app
cp .env.example .env  # add OPENAI_API_KEY
docker-compose up --build
```

### Deploy to AWS

See [terraform/README.md](terraform/README.md) for full instructions.

## CI/CD

GitHub Actions deploys on push to `main` using OIDC to assume IAM role (no long-lived secrets).

## Estimated Cost

Monthly cost for minimal deployment (us-east-1):

| Resource | Configuration | Cost |
|----------|---------------|------|
| ALB | Base + minimal traffic | ~$20 |
| NAT Gateway | 2 AZs (HA) | ~$65 |
| ECS Fargate | 1 task, 0.25 vCPU, 0.5GB | ~$10 |
| S3 + ECR | Minimal storage | <$1 |
| **Total** | | **~$95/month** |

Cost optimization:
- Single NAT Gateway (`single_nat_gateway = true`): saves ~$32/month
- Scale to zero when not in use: Fargate charges only for running tasks

## Design Decisions

### Infrastructure

**ECS Fargate over EC2**

Chose Fargate for serverless container orchestration. No need to manage EC2 instances, patch OS, or handle capacity planning. Pay only for task runtime. Trade-off: slightly higher per-hour cost than EC2, but operational simplicity wins for a small service. Scales to zero when not in use.

**Application Load Balancer**

ALB provides native WebSocket support with long-lived connections, automatic SSL termination via ACM certificates, and built-in health checks. Considered API Gateway + Lambda, but WebSocket streaming with large audio chunks fits better with containers. ALB handles connection upgrades transparently.

**Modular Terraform Structure**

Infrastructure split into 5 independent modules: network, ecr, alb, ecs-cluster, ecs-service. Each module has its own state file and can be updated independently. Benefits:
- Network changes don't risk application deployment
- ECR can exist before ECS is ready
- Multiple services can share the same cluster
- Easier to reason about and debug

**S3 for Audio Storage**

Original service saved audio files to local filesystem — these would be lost on container restart or redeployment. Moved to S3 for durability. Audio files are uploaded at the end of each session with timestamp-based keys. S3 lifecycle policies can be added later for automatic cleanup.

**S3 VPC Endpoint (Gateway type)**

Gateway endpoints for S3 are free (unlike Interface endpoints). Traffic to S3 stays within AWS network, bypassing NAT Gateway. For high-volume audio uploads, this significantly reduces data transfer costs. NAT Gateway charges $0.045/GB — with S3 endpoint, this becomes $0.

**Multi-AZ NAT Gateway**

Deployed NAT Gateway in each availability zone for high availability. If one AZ fails, tasks in the other AZ continue to function. For cost optimization in dev/staging, can switch to single NAT Gateway (variable `single_nat_gateway = true`).

### Security

**SSM Parameter Store for Secrets**

OpenAI API key stored in SSM Parameter Store as SecureString (encrypted with KMS). ECS task execution role retrieves it at container start and injects as environment variable. Benefits:
- No secrets in code, Docker images, or terraform state
- Audit trail via CloudTrail
- Easy rotation without redeployment

**Least-Privilege IAM**

Two separate IAM roles:
- *Execution role*: used by ECS agent to pull images from ECR and fetch secrets from SSM
- *Task role*: used by application code to upload files to S3

Each role has minimal permissions scoped to specific resources (exact SSM parameter ARN, exact S3 bucket ARN).

**Private Subnets**

ECS tasks run in private subnets with no public IP addresses. Only ALB is exposed to the internet in public subnets. Tasks reach external APIs (OpenAI) through NAT Gateway. This prevents direct access to containers from the internet.

### Application Improvements

Original service had several issues for production use:

1. **Local file storage → S3**: Files saved to container filesystem would be lost on restart. Now uploaded to S3 with `boto3`, persisted durably.

2. **Hardcoded paths → tempfile**: Whisper API requires a file, not bytes. Original code used hardcoded `audio_files/` directory. Now uses Python `tempfile` module — files are created in `/tmp`, used for API call, and immediately deleted.

3. **Health check endpoint**: Added `/health` endpoint returning `{"status": "ok"}`. Required for ALB target group health checks. Without it, ALB cannot determine if the container is healthy.

4. **ECS Exec enabled**: Added SSM permissions to task role for debugging. Allows `aws ecs execute-command` to shell into running containers.

### CI/CD

**GitHub Actions**

Simple and integrated with GitHub. Workflow triggers on push to `main` when application code changes. Steps:
1. Build Docker image tagged with git commit SHA
2. Push to ECR
3. Register new ECS task definition with updated image
4. Update ECS service to use new task definition

No complex blue/green or canary — ECS rolling update replaces tasks one by one. Each deployment is traceable to a specific commit.

Trade-off: CI/CD creates task definitions outside of Terraform, causing state drift in `ecs-service` module. Running `terraform apply` may revert to the image tag stored in state.

**Manual Trigger**

Workflow can be triggered manually via GitHub UI with optional custom image tag. Useful for:
- Deploying specific version
- Re-deploying without code changes
- Rollback to previous image
