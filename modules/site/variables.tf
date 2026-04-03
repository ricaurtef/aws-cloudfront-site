############################
# DNS
############################

variable "domain_name" {
  description = "Apex domain name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Must be a valid domain name (e.g., example.com)."
  }
}

############################
# S3
############################

variable "site_bucket_name" {
  description = "Name of the S3 bucket for site content."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.site_bucket_name))
    error_message = "Must be a valid S3 bucket name (lowercase, 3-63 chars, no underscores)."
  }
}
