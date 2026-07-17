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

variable "ami_owner_account_id" {
  type    = string
  default = "111111111111"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  type        = string
  default     = "dev-servers"
}