############################
# General
############################

region      = "us-east-1"
environment = "production"

############################
# IAM
############################

deploy_role_arn = "arn:aws:iam::839765241276:role/github-actions-deploy"

############################
# Site
############################

google_site_verification = "google-site-verification=-ZffudtJxZqRKlZrY67G6odnVxW6codnQsl-gjA3SRE"
domain_name              = "ricaurtef.com"
site_bucket_name         = "ricaurtef-site-content"
preview_bucket_name      = "ricaurtef-site-preview"

############################
# Alerts
############################

powertools_layer_version  = 30
sns_alerts_topic_name     = "cloudfront-alerts"
alarm_request_threshold   = 10000
alarm_4xx_min_requests    = 100
lambda_log_retention_days = 14
