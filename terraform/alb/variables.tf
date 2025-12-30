variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name used as prefix for resources"
  default     = "streaming"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the service (e.g., example.com)"
}
