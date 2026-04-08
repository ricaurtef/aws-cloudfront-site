############################
# S3
############################

moved {
  from = aws_s3_bucket.this_content
  to   = aws_s3_bucket.content
}

moved {
  from = aws_s3_bucket_public_access_block.this_content
  to   = aws_s3_bucket_public_access_block.content
}

moved {
  from = aws_s3_bucket_policy.this_content
  to   = aws_s3_bucket_policy.content
}

moved {
  from = aws_s3_bucket.this_logs
  to   = aws_s3_bucket.logs
}

moved {
  from = aws_s3_bucket_public_access_block.this_logs
  to   = aws_s3_bucket_public_access_block.logs
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.this_logs
  to   = aws_s3_bucket_lifecycle_configuration.logs
}

moved {
  from = aws_s3_bucket_ownership_controls.this_logs
  to   = aws_s3_bucket_ownership_controls.logs
}

############################
# ACM
############################

moved {
  from = aws_acm_certificate.this
  to   = aws_acm_certificate.site
}

moved {
  from = aws_route53_record.this_cert_validation["ricaurtef.com"]
  to   = aws_route53_record.cert_validation["ricaurtef.com"]
}

moved {
  from = aws_route53_record.this_cert_validation["*.ricaurtef.com"]
  to   = aws_route53_record.cert_validation["*.ricaurtef.com"]
}

moved {
  from = aws_acm_certificate_validation.this
  to   = aws_acm_certificate_validation.site
}

############################
# CloudFront
############################

moved {
  from = aws_cloudfront_origin_access_control.this
  to   = aws_cloudfront_origin_access_control.site
}

moved {
  from = aws_cloudfront_distribution.this
  to   = aws_cloudfront_distribution.site
}

moved {
  from = aws_cloudfront_function.this_redirect
  to   = aws_cloudfront_function.redirect
}

moved {
  from = aws_cloudfront_function.this_headers
  to   = aws_cloudfront_function.headers
}

############################
# Route 53
############################

moved {
  from = aws_route53_zone.this
  to   = aws_route53_zone.site
}

moved {
  from = aws_route53_record.this_apex_a
  to   = aws_route53_record.apex_a
}

moved {
  from = aws_route53_record.this_apex_aaaa
  to   = aws_route53_record.apex_aaaa
}

moved {
  from = aws_route53_record.this_www_a
  to   = aws_route53_record.www_a
}

moved {
  from = aws_route53_record.this_www_aaaa
  to   = aws_route53_record.www_aaaa
}

############################
# DNS Delegation
############################

moved {
  from = aws_route53domains_registered_domain.this
  to   = aws_route53domains_registered_domain.site
}
