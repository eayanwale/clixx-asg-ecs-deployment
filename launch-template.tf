resource "aws_launch_template" "tf-lt" {
  name_prefix   = "tf-${local.RUNNER}-${local.ORGANIZATION}-lt"
  description   = "Terraform launch template for AL2 Clixx instance"
  image_id      = data.aws_ami.stack.id
  instance_type = "t3.micro"
  key_name      = "dev-servers"

  ## Block devices
  # block_device_mappings {
  #   device_name = "/dev/xvda"
  #   ebs {
  #     delete_on_termination = true
  #     encrypted             = false
  #     iops                  = 3000
  #     throughput            = 125
  #     volume_type           = "gp3"
  #     volume_size           = 8
  #   }
  # }

  # block_device_mappings {
  #   device_name = "/dev/sdb"
  #   ebs {
  #     delete_on_termination = true
  #     encrypted             = false
  #     iops                  = 3000
  #     throughput            = 125
  #     volume_type           = "gp3"
  #     volume_size           = 8

  #   }
  # }

  # block_device_mappings {
  #   device_name = "/dev/sdc"
  #   ebs {
  #     delete_on_termination = true
  #     encrypted             = false
  #     iops                  = 3000
  #     throughput            = 125
  #     volume_type           = "gp3"
  #     volume_size           = 8
  #   }
  # }

  # block_device_mappings {
  #   device_name = "/dev/sdd"
  #   ebs {
  #     delete_on_termination = true
  #     encrypted             = false
  #     iops                  = 3000
  #     throughput            = 125
  #     volume_type           = "gp3"
  #     volume_size           = 8
  #   }
  # }

  # block_device_mappings {
  #   device_name = "/dev/sde"
  #   ebs {
  #     delete_on_termination = true
  #     encrypted             = false
  #     iops                  = 3000
  #     throughput            = 125
  #     volume_type           = "gp3"
  #     volume_size           = 8
  #   }
  # }
  #
  #
  iam_instance_profile {
    arn = local.INSTANCE_ROLE
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.clixx-sg.id]
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    export database_endpoint='${aws_db_instance.clixx.endpoint}'
    export database_name='${aws_db_instance.clixx.db_name}'
    export database_user='${aws_db_instance.clixx.username}'
    export database_pass='${data.aws_ssm_parameter.db_password.value}'
    export lb_dns_name='${aws_lb.tf-lb.dns_name}'
    export file_system_id='${aws_efs_file_system.clixx-code-fs.id}'
    export GIT_REPO='${local.GIT_REPO}'
    ${local.script_content}
    EOT
  )

  #user_data = base64encode(file("${path.module}/scripts/test-connect.sh"))

  tags = {
    name = "tf-${local.RUNNER}-${local.ORGANIZATION}-instance"
  }
}