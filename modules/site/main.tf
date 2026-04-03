############################
# S3 — Content Bucket
############################

resource "aws_s3_bucket" "this_content" {
  bucket = var.site_bucket_name
}

resource "aws_s3_bucket_public_access_block" "this_content" {
  bucket                  = aws_s3_bucket.this_content.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this_content" {
  bucket = aws_s3_bucket.this_content.id
  policy = data.aws_iam_policy_document.this.json
}

############################
# S3 — Access Logs Bucket
############################

resource "aws_s3_bucket" "this_logs" {
  bucket = "${var.site_bucket_name}-logs"
}

resource "aws_s3_bucket_public_access_block" "this_logs" {
  bucket                  = aws_s3_bucket.this_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this_logs" {
  bucket = aws_s3_bucket.this_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this_logs" {
  bucket = aws_s3_bucket.this_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

############################
# ACM Certificate (us-east-1)
############################

resource "aws_acm_certificate" "this" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "this_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.this_cert_validation : r.fqdn]
}

############################
# CloudFront Distribution
############################

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.domain_name
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http3"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.this_content.bucket_regional_domain_name
    origin_id                = "s3-content"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-content"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this_redirect.arn
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.this_headers.arn
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
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
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
    bucket          = aws_s3_bucket.this_logs.bucket_domain_name
    prefix          = "cloudfront/"
  }

  depends_on = [aws_acm_certificate_validation.this]
}

############################
# CloudFront Functions
############################

resource "aws_cloudfront_function" "this_redirect" {
  name    = "redirect-www"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/functions/redirect-www.js")
}

resource "aws_cloudfront_function" "this_headers" {
  name    = "security-headers"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/functions/security-headers.js")
}

############################
# Route 53 DNS
############################

resource "aws_route53_zone" "this" {
  name = var.domain_name
}

# Apex — A + AAAA alias to CloudFront
resource "aws_route53_record" "this_apex_a" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "this_apex_aaaa" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# www — A + AAAA alias to CloudFront (redirected by CloudFront Function)
resource "aws_route53_record" "this_www_a" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "this_www_aaaa" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "www.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
