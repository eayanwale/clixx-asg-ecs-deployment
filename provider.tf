provider "aws" {
  region  = var.AWS_REGION
  profile = "stackprog-dev"
  #   assume_role {
  #   role_arn = "arn:aws:iam::222222222222:role/Engineer"
  # }

  default_tags {
    tags = {
      ManagedBy   = "${var.ManagedBy}"
      Environment = "${var.ENVIRONMENT}"
      CreatedBy   = "${local.RUNNER}"
      Purpose     = "${var.usage}"
    }
  }
}

provider "aws" {
  alias  = "domain_account"
  region = var.AWS_REGION
  # profile = "stackprog-mgmt"

  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/Engineer"
  }
}