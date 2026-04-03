provider "aws" {
  region = var.region

  assume_role {
    role_arn = var.deploy_role_arn
  }

  default_tags {
    tags = {
      managed_by  = "terraform"
      project     = "aws-cloudfront-site"
      repository  = "https://github.com/ricaurtef/aws-cloudfront-site"
      environment = var.environment
    }
  }
}

# ACM certificates for CloudFront must be in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  assume_role {
    role_arn = var.deploy_role_arn
  }

  default_tags {
    tags = {
      managed_by  = "terraform"
      project     = "aws-cloudfront-site"
      repository  = "https://github.com/ricaurtef/aws-cloudfront-site"
      environment = var.environment
    }
  }
}

# Management account — domain registrar (no assume_role, uses OIDC role directly).
provider "aws" {
  alias  = "management"
  region = "us-east-1"
}
