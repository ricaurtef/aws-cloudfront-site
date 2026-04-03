module "site" {
  source = "./modules/site"

  domain_name      = var.domain_name
  site_bucket_name = var.site_bucket_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
