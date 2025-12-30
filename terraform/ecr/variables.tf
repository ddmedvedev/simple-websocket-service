variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name used as prefix for resources"
  default     = "streaming"
}
