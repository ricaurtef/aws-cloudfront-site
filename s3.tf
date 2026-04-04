############################
# IAM Policy Documents
############################

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this_content.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

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
