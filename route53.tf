# resource "aws_route53_record" "clixx-subdomain" {
#   zone_id = data.aws_route53_zone.root-domain.zone_id
#   name    = ""
#   type    = "A"

#   alias {
#     name                   = aws_lb.ecs-lb.dns_name
#     zone_id                = aws_lb.ecs-lb.zone_id
#     evaluate_target_health = true
#   }
# }

resource "aws_route53_record" "ecs-clixx-subdomain" {
  zone_id = data.aws_route53_zone.root-domain.zone_id
  name    = "ecs"
  type    = "A"

  alias {
    name                   = aws_lb.ecs-lb.dns_name
    zone_id                = aws_lb.ecs-lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "asg-clixx-subdomain" {
  zone_id = data.aws_route53_zone.root-domain.zone_id
  name    = "asg"
  type    = "A"

  alias {
    name                   = aws_lb.tf-lb.dns_name
    zone_id                = aws_lb.tf-lb.zone_id
    evaluate_target_health = true
  }
}
