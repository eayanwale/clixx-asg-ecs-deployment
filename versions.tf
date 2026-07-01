terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket  = "enoch-tf-state-bucket"
    key     = "stack-aut-Clixx/terraform.tfstate"
    region  = "us-east-1"
    profile = "stackprog-dev"
    # assume_role {
    #   role_arn = "arn:aws:iam::333333333333:role/Engineer"
    # }
    # use_lockfile = true
  }
}
