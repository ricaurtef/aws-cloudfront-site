############################
# General
############################

variable "region" {
  description = "AWS region for primary resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Must be a valid AWS region (e.g., us-east-1)."
  }
}

variable "environment" {
  description = "Deployment environment (e.g., production, staging)."
  type        = string

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Must be one of: production, staging, development."
  }
}

############################
# IAM
############################

variable "deploy_role_arn" {
  description = "ARN of the IAM role to assume for deploying resources (hub-and-spoke)."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.deploy_role_arn))
    error_message = "Must be a valid IAM role ARN."
  }
}

############################
# Site
############################

variable "domain_name" {
  description = "Apex domain name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Must be a valid domain name (e.g., example.com)."
  }
}

variable "google_site_verification" {
  description = "Google Search Console DNS verification token."
  type        = string

  validation {
    condition     = can(regex("^google-site-verification=", var.google_site_verification))
    error_message = "Must start with google-site-verification=."
  }
}

variable "site_bucket_name" {
  description = "Name of the S3 bucket for site content."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.site_bucket_name))
    error_message = "Must be a valid S3 bucket name (lowercase, 3-63 chars, no underscores)."
  }
}

variable "preview_bucket_name" {
  description = "Name of the S3 bucket for preview site content."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.preview_bucket_name))
    error_message = "Must be a valid S3 bucket name (lowercase, 3-63 chars, no underscores)."
  }
}

############################
# Alerts
############################

variable "powertools_layer_version" {
  description = "Version number of the AWS Lambda Powertools Python layer (arm64)."
  type        = number

  validation {
    condition     = var.powertools_layer_version > 0
    error_message = "Must be a positive number."
  }
}

variable "sns_alerts_topic_name" {
  description = "Name of the SNS topic for CloudFront alarm notifications."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.sns_alerts_topic_name))
    error_message = "Must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "alarm_request_threshold" {
  description = "Request count threshold per 5-minute period for the CloudFront request spike alarm."
  type        = number

  validation {
    condition     = var.alarm_request_threshold > 0
    error_message = "Must be a positive number."
  }
}

variable "alarm_4xx_min_requests" {
  description = <<-EOT
    Minimum total requests per 5-minute period before the CloudFront 4xx error-rate alarm evaluates.
    Prevents scanner 404s from pegging the ratio on low-traffic windows.
  EOT
  type        = number

  validation {
    condition     = var.alarm_4xx_min_requests > 0
    error_message = "Must be a positive number."
  }
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain CloudWatch logs for Lambda functions."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.lambda_log_retention_days)
    error_message = "Must be a valid CloudWatch log retention value."
  }
}
