locals {
  RUNNER         = "asg-clixx"
  ORGANIZATION   = data.aws_ssm_parameter.organization.value
  ROLE_NAME      = data.aws_ssm_parameter.role_name.value
  GIT_REPO       = data.aws_ssm_parameter.git_repo.value
  INSTANCE_ROLE  = data.aws_ssm_parameter.instanceProfile.value
  script_content = file("${path.module}/scripts/user-data.sh")
}
