variable "AWS_REGION" {
  type    = string
  default = "us-east-1"
}

variable "usage" {
  type    = string
  default = "clixx retail application"
}

variable "ENVIRONMENT" {
  type    = string
  default = "Development"
}

variable "ManagedBy" {
  default = "terraform"
}

variable "ami_owner_account_id" {
  type    = string
  default = "111111111111"
}

variable "ecr_image_tag" {
  description = "Tag to deploy from clixx-repository"
  type        = string
  default     = "clixx-image-latest"
}

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  type        = string
  default     = "dev-servers"
}