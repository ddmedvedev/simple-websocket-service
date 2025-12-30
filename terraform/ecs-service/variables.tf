variable "region" {
  type    = string
  default = "us-east-1"
}

variable "service_name" {
  type        = string
  description = "Name of the service"
  default     = "simple-websocket-service"
}

variable "container_port" {
  type        = number
  description = "Port the container listens on"
  default     = 8000
}

variable "cpu" {
  type        = number
  description = "CPU units for the task (1024 = 1 vCPU)"
  default     = 256
}

variable "memory" {
  type        = number
  description = "Memory for the task in MB"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Desired number of tasks"
  default     = 1
}

variable "image_tag" {
  type        = string
  description = "Docker image tag"
  default     = "latest"
}
