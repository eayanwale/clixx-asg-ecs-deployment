data "aws_ssm_parameter" "db_password" {
  name            = "/stack/clixx/db_password"
  with_decryption = true
}

data "aws_ssm_parameter" "organization" {
  name = "/stack/orgname"
}

data "aws_ssm_parameter" "role_name" {
  name = "/stack/role"
}

data "aws_ssm_parameter" "git_repo" {
  name = "/stack/clixx/repo"
}

data "aws_ssm_parameter" "instanceProfile" {
  name = "/stack/instanceProfile"
}

data "aws_instances" "asg_nodes" {
  instance_state_names = ["running"]

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.tf-asg.name]
  }
}

data "aws_ami" "stack" {
  owners     = [ var.ami_owner_account_id ]
  most_recent      = true

  filter {
    name   = "name"
    values = ["ami-stack-*"]
  }
}
