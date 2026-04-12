############################
# CloudWatch — Dashboard
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

############################
# CloudWatch — Alarms
############################

resource "aws_cloudwatch_metric_alarm" "error_5xx" {
  alarm_name          = "cloudfront-5xx-error-rate"
  alarm_description   = "CloudFront 5xx error rate >= 5% for 10 minutes."
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  period              = 300
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "error_4xx" {
  alarm_name          = "cloudfront-4xx-error-rate"
  alarm_description   = "CloudFront 4xx error rate >= 15% for 10 minutes."
  namespace           = "AWS/CloudFront"
  metric_name         = "4xxErrorRate"
  statistic           = "Average"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 15
  period              = 300
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "request_spike" {
  alarm_name          = "cloudfront-request-spike"
  alarm_description   = "CloudFront request count >= ${var.alarm_request_threshold} in 5 minutes."
  namespace           = "AWS/CloudFront"
  metric_name         = "Requests"
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.alarm_request_threshold
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

############################
# SNS — Alert Notifications
############################

resource "aws_sns_topic" "alerts" {
  name = var.sns_alerts_topic_name
}

resource "aws_sns_topic_subscription" "telegram" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.telegram_notify.arn
}

############################
# SSM — Telegram Credentials
############################

resource "aws_ssm_parameter" "telegram_bot_token" {
  name  = "/alerting/telegram/bot-token"
  type  = "SecureString"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "telegram_chat_id" {
  name  = "/alerting/telegram/chat-id"
  type  = "SecureString"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

############################
# Lambda — Telegram Notify
############################

resource "aws_lambda_function" "telegram_notify" {
  function_name    = "telegram-notify"
  description      = "Forwards CloudWatch Alarm notifications to Telegram."
  runtime          = "python3.14"
  architectures    = ["arm64"]
  handler          = "lambda_function.handler"
  memory_size      = 128
  timeout          = 10
  role             = aws_iam_role.telegram_notify.arn
  filename         = data.archive_file.telegram_notify.output_path
  source_code_hash = data.archive_file.telegram_notify.output_base64sha256

  layers = [data.aws_ssm_parameter.powertools_layer_arn.value]

  environment {
    variables = {
      SSM_BOT_TOKEN_PATH      = aws_ssm_parameter.telegram_bot_token.name
      SSM_CHAT_ID_PATH        = aws_ssm_parameter.telegram_chat_id.name
      POWERTOOLS_LOG_LEVEL    = "INFO"
      POWERTOOLS_SERVICE_NAME = "telegram-notify"
    }
  }
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_notify.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

############################
# IAM — Telegram Notify
############################

resource "aws_iam_role" "telegram_notify" {
  name               = "telegram-notify-lambda"
  assume_role_policy = data.aws_iam_policy_document.telegram_notify_assume.json
}

resource "aws_iam_role_policy" "telegram_notify" {
  name   = "telegram-notify"
  role   = aws_iam_role.telegram_notify.id
  policy = data.aws_iam_policy_document.telegram_notify.json
}

############################
# CloudWatch — Lambda Logs
############################

resource "aws_cloudwatch_log_group" "telegram_notify" {
  name              = "/aws/lambda/${aws_lambda_function.telegram_notify.function_name}"
  retention_in_days = var.lambda_log_retention_days
}
