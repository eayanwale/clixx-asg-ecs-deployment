data "aws_route53_zone" "root-domain" {
  provider = aws.domain_account

  name         = "example.com"
  private_zone = false
}

resource "aws_route53_record" "clixx-subdomain" {
  provider = aws.domain_account

  zone_id = data.aws_route53_zone.root-domain.id
  name    = "clixx.example.com"
  type    = "CNAME"
  ttl     = "30"

  records = [aws_lb.tf-lb.dns_name]
}