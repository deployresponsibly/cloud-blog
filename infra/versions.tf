terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

# Everything lives in us-east-1: CloudFront ACM certificates, CLOUDFRONT-scope
# WAF web ACLs and the Pricing Plan Manager API are all us-east-1 only.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "cloud-blog"
      ManagedBy = "terraform"
    }
  }
}

provider "awscc" {
  region = "us-east-1"
}

# The domain is registered, and its public hosted zone lives, in a different
# account than the site. DNS records (zone lookup, ACM validation, alias and CAA
# records) go through this alias.
provider "aws" {
  alias   = "dns"
  region  = "us-east-1"
  profile = var.dns_profile
}
