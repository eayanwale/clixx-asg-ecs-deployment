resource "aws_efs_file_system" "clixx-code-fs" {
  creation_token = "tf-${local.RUNNER}-code-fs"

  tags = {
    Name = "tf-${local.RUNNER}-app_code-fs"
  }
}

resource "aws_efs_mount_target" "clixx-code-fs-mt" {
  for_each = {
    a = aws_subnet.private-subnet-a.id
    b = aws_subnet.private-subnet-b.id
  }

  file_system_id  = aws_efs_file_system.clixx-code-fs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs-sg.id]
}

resource "aws_instance" "bastion" {
  ami                         = "ami-0123456789abcdef0"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-bastion-server"
  }
}

resource "aws_lb_target_group" "tf-tg" {
  name     = "tf-${local.RUNNER}-${local.ORGANIZATION}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200,301,302"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-tg"
  }
}

resource "aws_lb_target_group" "ecs-tg" {
  name        = "tf-${local.RUNNER}-container-TG"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled  = true
    path     = "/"
    port     = "traffic-port"
    protocol = "HTTP"
    matcher  = "200,301,302"
  }
}

resource "aws_lb" "tf-lb" {
  name               = "tf-${local.RUNNER}-${local.ORGANIZATION}-lb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public-subnet-a.id, aws_subnet.public-subnet-b.id]

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-lb"
  }
}

resource "aws_lb" "ecs-lb" {
  name               = "tf-${local.RUNNER}-${local.ORGANIZATION}-ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [aws_subnet.public-subnet-a.id, aws_subnet.public-subnet-b.id]

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-lb"
  }
}

resource "aws_lb_listener" "tf-lb-lsnr" {
  load_balancer_arn = aws_lb.tf-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-lb-listener"
  }
}

resource "aws_lb_listener" "tf-lb-lsnr-https" {
  load_balancer_arn = aws_lb.tf-lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:us-east-1:222222222222:certificate/00000000-0000-0000-0000-000000000000"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tf-tg.arn
  }

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-lb-listener-https"
  }
}

resource "aws_lb_listener" "ecs-lsnr" {
  load_balancer_arn = aws_lb.ecs-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name = "tf-${local.RUNNER}-${local.ORGANIZATION}-lb-listener"
  }
}

resource "aws_lb_listener" "ecs-lsnr-https" {
  load_balancer_arn = aws_lb.ecs-lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:us-east-1:222222222222:certificate/00000000-0000-0000-0000-000000000000"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-tg.arn
  }
}

resource "aws_autoscaling_group" "tf-asg" {
  depends_on = [aws_db_instance.clixx]

  name                      = "tf-${local.RUNNER}-${local.ORGANIZATION}-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_type         = "ELB"
  health_check_grace_period = 700
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.private-subnet-a.id, aws_subnet.private-subnet-b.id]
  target_group_arns         = [aws_lb_target_group.tf-tg.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      auto_rollback          = true
      instance_warmup        = 700
      min_healthy_percentage = 50
    }
  }

  launch_template {
    id      = aws_launch_template.tf-lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "tf-${local.RUNNER}-${local.ORGANIZATION}-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "ecs-asg" {
  depends_on = [aws_db_instance.clixx-ecs-db]

  name                = "tf-${local.RUNNER}-${local.ORGANIZATION}-ecs-asg"
  vpc_zone_identifier = [aws_subnet.private-subnet-a.id, aws_subnet.private-subnet-b.id]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.clixx-ecs-lt.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "cpu-target-policy"
  autoscaling_group_name = aws_autoscaling_group.tf-asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
}

