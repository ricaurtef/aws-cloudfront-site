############################
# S3
############################

moved {
  from = module.site.aws_s3_bucket.this_content
  to   = aws_s3_bucket.this_content
}

moved {
  from = module.site.aws_s3_bucket_public_access_block.this_content
  to   = aws_s3_bucket_public_access_block.this_content
}

moved {
  from = module.site.aws_s3_bucket_policy.this_content
  to   = aws_s3_bucket_policy.this_content
}

moved {
  from = module.site.aws_s3_bucket.this_logs
  to   = aws_s3_bucket.this_logs
}

moved {
  from = module.site.aws_s3_bucket_public_access_block.this_logs
  to   = aws_s3_bucket_public_access_block.this_logs
}

moved {
  from = module.site.aws_s3_bucket_lifecycle_configuration.this_logs
  to   = aws_s3_bucket_lifecycle_configuration.this_logs
}

moved {
  from = module.site.aws_s3_bucket_ownership_controls.this_logs
  to   = aws_s3_bucket_ownership_controls.this_logs
}

############################
# ACM
############################

moved {
  from = module.site.aws_acm_certificate.this
  to   = aws_acm_certificate.this
}

moved {
  from = module.site.aws_route53_record.this_cert_validation["ricaurtef.com"]
  to   = aws_route53_record.this_cert_validation["ricaurtef.com"]
}

moved {
  from = module.site.aws_route53_record.this_cert_validation["*.ricaurtef.com"]
  to   = aws_route53_record.this_cert_validation["*.ricaurtef.com"]
}

moved {
  from = module.site.aws_acm_certificate_validation.this
  to   = aws_acm_certificate_validation.this
}

############################
# CloudFront
############################

moved {
  from = module.site.aws_cloudfront_origin_access_control.this
  to   = aws_cloudfront_origin_access_control.this
}

moved {
  from = module.site.aws_cloudfront_distribution.this
  to   = aws_cloudfront_distribution.this
}

moved {
  from = module.site.aws_cloudfront_function.this_redirect
  to   = aws_cloudfront_function.this_redirect
}

moved {
  from = module.site.aws_cloudfront_function.this_headers
  to   = aws_cloudfront_function.this_headers
}

############################
# Route 53
############################

moved {
  from = module.site.aws_route53_zone.this
  to   = aws_route53_zone.this
}

moved {
  from = module.site.aws_route53_record.this_apex_a
  to   = aws_route53_record.this_apex_a
}

moved {
  from = module.site.aws_route53_record.this_apex_aaaa
  to   = aws_route53_record.this_apex_aaaa
}

moved {
  from = module.site.aws_route53_record.this_www_a
  to   = aws_route53_record.this_www_a
}

moved {
  from = module.site.aws_route53_record.this_www_aaaa
  to   = aws_route53_record.this_www_aaaa
}
