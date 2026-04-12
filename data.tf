############################
# Archive — Lambda Packages
############################

data "archive_file" "telegram_notify" {
  type        = "zip"
  source_file = "${path.module}/functions/telegram-notify/lambda_function.py"
  output_path = "${path.module}/functions/telegram-notify/lambda_function.zip"
}

############################
# Lambda — Powertools Layer
############################

data "aws_lambda_layer_version" "powertools" {
  layer_name         = "arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python314-arm64"
  compatible_runtime = "python3.14"
}

############################
# IAM Policy Documents — Telegram Notify
############################

data "aws_iam_policy_document" "telegram_notify_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "telegram_notify" {
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.telegram_notify.arn}:*"]
  }

  statement {
    sid     = "SSMGetParameters"
    actions = ["ssm:GetParameter"]
    resources = [
      aws_ssm_parameter.telegram_bot_token.arn,
      aws_ssm_parameter.telegram_chat_id.arn,
    ]
  }

  statement {
    sid       = "KMSDecrypt"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.us-east-1.amazonaws.com"]
    }
  }
}

############################
# IAM Policy Documents — Preview
############################

data "aws_iam_policy_document" "preview" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.preview_content.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.preview.arn]
    }
  }
}

############################
# IAM Policy Documents — Production
############################

data "aws_iam_policy_document" "content_bucket" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.content.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}
