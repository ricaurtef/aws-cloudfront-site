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
