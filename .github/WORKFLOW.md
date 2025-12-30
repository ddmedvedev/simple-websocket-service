# CI/CD

GitHub Actions workflow for automated deployment to AWS ECS.

## Workflow

**File:** `workflows/deploy.yml`

### Triggers

- **Push to `main`** — automatic deploy when changes in:
  - `app/**`
  - `Dockerfile`
  - `.github/workflows/deploy.yml`

- **Manual** — Actions → Deploy to ECS → Run workflow

### Steps

1. Checkout code
2. Configure AWS credentials
3. Login to ECR
4. Build and push Docker image (tag: commit SHA only)
5. Update ECS task definition with new image
6. Update ECS service with new task definition

## Required Configuration

### 1. GitHub Variable

Configure in: Settings → Secrets and variables → Actions → Variables

| Variable | Description |
|----------|-------------|
| `AWS_ROLE_ARN` | ARN of IAM role to assume (e.g., `arn:aws:iam::123456789012:role/github-actions-deploy`) |

### 2. AWS IAM Role

Create IAM role with trust policy for GitHub OIDC:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

### 3. OIDC Provider (one-time per AWS account)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## Manual Deploy with Custom Tag

1. Go to Actions → Deploy to ECS
2. Click "Run workflow"
3. Optionally specify image tag (default: git SHA)

## Environment Variables

| Variable | Value |
|----------|-------|
| `AWS_REGION` | us-east-1 |
| `ECR_REPOSITORY` | streaming |
| `ECS_CLUSTER` | streaming-cluster |
| `ECS_SERVICE` | simple-websocket-service |
