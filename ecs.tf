resource "aws_iam_role" "ecs_instance_role" {
  name = "clixx-ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  for_each = var.ec2_role_policies

  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "clixx-ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_ecs_cluster" "clixx-cluster" {
  name = "tf-${local.RUNNER}-${local.ORGANIZATION}-Cluster"
}

resource "aws_ecs_capacity_provider" "clixx-cp" {
  name = "tf-${local.RUNNER}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs-asg.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "clixx-ccp" {
  cluster_name       = aws_ecs_cluster.clixx-cluster.name
  capacity_providers = [aws_ecs_capacity_provider.clixx-cp.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.clixx-cp.name
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "clixx" {
  family                   = "tf-${local.RUNNER}-task-definition"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"

  container_definitions = jsonencode([
    {
      name              = "tf-${local.RUNNER}-container"
      image             = "${data.aws_ecr_repository.clixx-repository.repository_url}:${var.ecr_image_tag}"
      essential         = true
      memoryReservation = 512
      environment = [
        { name = "WORDPRESS_DB_HOST", value = aws_db_instance.clixx-ecs-db.address },
        { name = "WORDPRESS_DB_NAME", value = aws_db_instance.clixx-ecs-db.db_name },
        { name = "WORDPRESS_DB_USER", value = aws_db_instance.clixx-ecs-db.username },
        { name = "WORDPRESS_DB_PASSWORD", value = data.aws_ssm_parameter.db_password.value },
        { name = "WORDPRESS_CONFIG_EXTRA", value = "define('WP_HOME','https://ecs.clixx.example.com'); define('WP_SITEURL','https://ecs.clixx.example.com'); define('WP_DEBUG', true); define('WP_DEBUG_DISPLAY', true); define('WP_DEBUG_LOG', false);" }
      ]
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "clixx" {
  name            = "tf-${local.RUNNER}-ECS-SERVICE"
  cluster         = aws_ecs_cluster.clixx-cluster.id
  task_definition = aws_ecs_task_definition.clixx.arn
  desired_count   = 1
  launch_type     = "EC2"
  force_delete    = true

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 200

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-tg.arn
    container_name   = "tf-${local.RUNNER}-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.ecs-lsnr, aws_autoscaling_group.ecs-asg]
}
