############################
# CloudFront
############################

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (used for cache invalidation)."
  value       = aws_cloudfront_distribution.site.id
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
  value       = aws_route53_zone.site.name_servers
}

############################
# Preview
############################

output "preview_cloudfront_distribution_id" {
  description = "Preview CloudFront distribution ID (used for cache invalidation)."
  value       = aws_cloudfront_distribution.preview.id
}

output "preview_site_url" {
  description = "Public URL of the preview site."
  value       = "https://preview.${var.domain_name}"
}
