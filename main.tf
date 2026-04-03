module "site" {
  source = "./modules/site"

  domain_name      = var.domain_name
  site_bucket_name = var.site_bucket_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

############################
# DNS Delegation
############################

resource "aws_route53domains_registered_domain" "this" {
  provider    = aws.management
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = module.site.name_servers

    content {
      name = name_server.value
    }
  }
}
