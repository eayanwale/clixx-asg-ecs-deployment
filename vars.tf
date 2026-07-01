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