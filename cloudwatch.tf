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
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
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
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
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
            ["AWS/CloudFront", "4xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
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
            ["AWS/CloudFront", "BytesDownloaded", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"],
            ["AWS/CloudFront", "BytesUploaded", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
          ]
        }
      }
    ]
  })
}
