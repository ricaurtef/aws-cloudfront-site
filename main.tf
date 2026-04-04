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
# Google Search Console
############################

resource "aws_route53_record" "google_verification" {
  zone_id = module.site.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = [var.google_site_verification]
}

############################
# CloudWatch Dashboard
############################

resource "aws_cloudwatch_dashboard" "site" {
  dashboard_name = "ricaurtef-site"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title   = "Requests"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", module.site.cloudfront_distribution_id, "Region", "Global"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title   = "Cache Hit Rate (%)"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", module.site.cloudfront_distribution_id, "Region", "Global"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title   = "Error Rates (%)"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", module.site.cloudfront_distribution_id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", module.site.cloudfront_distribution_id, "Region", "Global"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title   = "Bandwidth (Bytes)"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", module.site.cloudfront_distribution_id, "Region", "Global"],
            ["AWS/CloudFront", "BytesUploaded", "DistributionId", module.site.cloudfront_distribution_id, "Region", "Global"]
          ]
        }
      }
    ]
  })
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
