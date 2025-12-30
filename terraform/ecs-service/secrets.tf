# SSM Parameter for OpenAI API Key
# Create manually via AWS CLI:
# aws ssm put-parameter --name "/ecs/simple-websocket-service/OPENAI_API_KEY" --value "sk-..." --type SecureString

data "aws_ssm_parameter" "openai_api_key" {
  name = "/ecs/${var.service_name}/OPENAI_API_KEY"
}
