############################
# S3 — Preview Content Bucket
############################

resource "aws_s3_bucket" "preview_content" {
  bucket = var.preview_bucket_name
}

resource "aws_s3_bucket_public_access_block" "preview_content" {
  bucket                  = aws_s3_bucket.preview_content.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "preview_content" {
  bucket = aws_s3_bucket.preview_content.id
  policy = data.aws_iam_policy_document.preview.json
}

resource "aws_s3_bucket_lifecycle_configuration" "preview_content" {
  bucket = aws_s3_bucket.preview_content.id

  rule {
    id     = "expire-preview-content"
    status = "Enabled"

    expiration {
      days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

############################
# CloudFront — Preview Distribution
############################

resource "aws_cloudfront_origin_access_control" "preview" {
  name                              = "preview.${var.domain_name}"
  description                       = "OAC for preview.${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "preview" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http3"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = ["preview.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.preview_content.bucket_regional_domain_name
    origin_id                = "s3-preview-content"
    origin_access_control_id = aws_cloudfront_origin_access_control.preview.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-preview-content"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect.arn
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.headers.arn
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "preview/"
  }

  depends_on = [aws_acm_certificate_validation.site]
}

############################
# Route 53 — Preview DNS
############################

resource "aws_route53_record" "preview_a" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "preview.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.preview.domain_name
    zone_id                = aws_cloudfront_distribution.preview.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "preview_aaaa" {
  zone_id = aws_route53_zone.site.zone_id
  name    = "preview.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.preview.domain_name
    zone_id                = aws_cloudfront_distribution.preview.hosted_zone_id
    evaluate_target_health = false
  }
}
