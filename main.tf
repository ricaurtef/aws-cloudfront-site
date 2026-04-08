############################
# DNS Delegation
############################

resource "aws_route53domains_registered_domain" "site" {
  provider    = aws.management
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = aws_route53_zone.site.name_servers

    content {
      name = name_server.value
    }
  }
}
