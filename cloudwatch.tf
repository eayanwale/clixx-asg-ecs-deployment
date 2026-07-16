resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  for_each = {
    "ecs" = aws_autoscaling_group.ecs-asg.name
    "asg" = aws_autoscaling_group.tf-asg.name
  }

  alarm_name          = "${each.key}-high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors the average CPU utilization across all instances in the ASG."

  dimensions = {
    AutoScalingGroupName = each.value
  }

  alarm_actions = [aws_sns_topic.warn.arn]
  ok_actions    = [aws_sns_topic.warn.arn]
}

resource "aws_cloudwatch_metric_alarm" "mem_usage" {
  for_each = {
    "ecs" = aws_autoscaling_group.ecs-asg.name
    "asg" = aws_autoscaling_group.tf-asg.name
  }

  # 1. Fixed: Unique alarm name using each.key
  alarm_name          = "${each.key}-high-mem-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"

  # 2. Fixed: Exact default Linux metric name from CWAgent
  metric_name       = "mem_used_percent"
  namespace         = "CWAgent"
  period            = "300"
  statistic         = "Average"
  threshold         = "85"
  alarm_description = "This metric monitors the average memory utilization across all instances in the ${each.value} ASG."

  dimensions = {
    AutoScalingGroupName = each.value
  }

  alarm_actions = [aws_sns_topic.warn.arn]
  ok_actions    = [aws_sns_topic.warn.arn]
}


resource "aws_cloudwatch_metric_alarm" "disk_usage" {
  for_each = {
    "ecs" = aws_autoscaling_group.ecs-asg.name
    "asg" = aws_autoscaling_group.tf-asg.name
  }

  alarm_name          = "${each.key}-high-disk-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  threshold           = "85"
  alarm_description   = "Monitors aggregate root disk utilization across all instances in the ${each.value} ASG."

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = "disk_used_percent"
      namespace   = "CWAgent"
      period      = "300"
      stat        = "Average"

      dimensions = {
        AutoScalingGroupName = each.value
        path                 = "/"
      }
    }
  }

  alarm_actions = [aws_sns_topic.warn.arn]
  ok_actions    = [aws_sns_topic.warn.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "clixx-${each.key}-dashboard"

  for_each = {
    "ecs" = aws_autoscaling_group.ecs-asg.name
    "asg" = aws_autoscaling_group.tf-asg.name
  }

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 7
        width  = 3
        height = 3

        properties = {
          markdown = "CLIXX ${upper(each.key)} METRICS"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "AutoScalingGroupName",
              each.value
            ]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "EC2 Instance CPU"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 10
        width  = 6
        height = 4

        properties = {
          view = "singleValue"
          metrics = [
            [
              "CWAgent",
              "mem_used_percent",
              "AutoScalingGroupName",
              each.value
            ],
            [
              "CWAgent",
              "disk_used_percent",
              "AutoScalingGroupName",
              each.value,
              "path",
              "/",
              "fstype",
              "xfs"
            ]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Memory & Disk Usage (%)"
        }
      }
    ]
  })
}