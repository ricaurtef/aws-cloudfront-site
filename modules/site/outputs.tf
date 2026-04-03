############################
# CloudFront
############################

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (used for cache invalidation)."
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.this.domain_name
}

############################
# Site
############################

output "site_url" {
  description = "Public URL of the site."
  value       = "https://${var.domain_name}"
}

############################
# DNS
############################

output "name_servers" {
  description = "NS records to configure in the management account for DNS delegation."
  value       = aws_route53_zone.this.name_servers
}
