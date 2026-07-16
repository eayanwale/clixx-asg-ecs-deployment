resource "aws_sns_topic" "warn" {
  name = "clixx-warnings"
}

resource "aws_sns_topic_subscription" "warn_admin" {
  for_each = var.admin_emails

  topic_arn = aws_sns_topic.warn.arn
  protocol  = "email"
  endpoint  = each.value
}