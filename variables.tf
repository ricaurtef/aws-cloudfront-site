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

variable "site_bucket_name" {
  description = "Name of the S3 bucket for site content."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.site_bucket_name))
    error_message = "Must be a valid S3 bucket name (lowercase, 3-63 chars, no underscores)."
  }
}
