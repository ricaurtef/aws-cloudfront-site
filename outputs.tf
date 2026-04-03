############################
# CloudFront
############################

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (used for cache invalidation)."
  value       = module.site.cloudfront_distribution_id
}

############################
# Site
############################

output "site_url" {
  description = "Public URL of the site."
  value       = module.site.site_url
}

############################
# DNS
############################

output "name_servers" {
  description = "NS records to configure in the management account for DNS delegation."
  value       = module.site.name_servers
}
