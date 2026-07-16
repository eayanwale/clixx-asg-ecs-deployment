variable "AWS_REGION" {
  type    = string
  default = "us-east-1"
}

variable "availability_zones" {
  type    = set(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "usage" {
  type    = string
  default = "clixx retail application"
}

variable "admin_emails" {
  type = set(string)
  default = [
    "devops-alerts@example.com",
    "user2@example.com"
  ]
}

variable "ENVIRONMENT" {
  type    = string
  default = "Development"
}

variable "ManagedBy" {
  default = "terraform"
}

variable "ec2_role_policies" {
  type = set(string)
  default = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
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