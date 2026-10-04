data "aws_caller_identity" "current" {}

data "aws_route53_zone" "root" {
  provider     = aws.dns
  name         = var.root_domain
  private_zone = false
}

locals {
  site_fqdn   = var.root_domain
  www_fqdn    = "www.${var.root_domain}"
  bucket_name = "${replace(local.site_fqdn, ".", "-")}-${data.aws_caller_identity.current.account_id}"
}

# ---------------------------------------------------------------------------
# S3 origin (private; only CloudFront can read it, via OAC)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  # Must wait for the public access block, which otherwise races the policy put.
  depends_on = [aws_s3_bucket_public_access_block.site]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.site.arn }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.site.arn, "${aws_s3_bucket.site.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# TLS certificate (DNS-validated in the domain's hosted zone)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "site" {
  domain_name               = local.site_fqdn
  subject_alternative_names = [local.www_fqdn]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  provider = aws.dns

  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.root.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# WAF web ACL (required by every CloudFront flat-rate plan)
# Mirrors the console's one-click protection rule groups.
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "site" {
  name  = replace(local.site_fqdn, ".", "-")
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = {
      AWSManagedRulesCommonRuleSet          = 0
      AWSManagedRulesAmazonIpReputationList = 1
      AWSManagedRulesKnownBadInputsRuleSet  = 2
    }

    content {
      name     = "AWS-${rule.key}"
      priority = rule.value

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = rule.key
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = rule.key
      }
    }
  }

  # Per-IP rate limit. The Free plan allows IP-based rate limiting but only 5
  # WAF rules in total (managed groups + custom), so this is rule 4 of 5.
  # The plan fixes the evaluation window at 5 minutes.
  rule {
    name     = "RateLimitPerIp"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        limit                 = var.rate_limit_per_5min
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "RateLimitPerIp"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = replace(local.site_fqdn, ".", "-")
  }
}

# ---------------------------------------------------------------------------
# CloudFront
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = local.bucket_name
  description                       = "OAC for ${local.site_fqdn}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# The S3 REST origin does not resolve directory indexes, and Astro emits
# /posts/foo/index.html, so rewrite /posts/foo and /posts/foo/ to index.html.
# The same function sends www to the apex with a permanent redirect.
resource "aws_cloudfront_function" "directory_index" {
  name    = "${replace(local.site_fqdn, ".", "-")}-directory-index"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Redirect www to the apex, append index.html to directory-style URIs"

  code = <<-JS
    function handler(event) {
      var request = event.request;
      var host = request.headers.host.value;
      if (host === '${local.www_fqdn}') {
        var query = Object.keys(request.querystring)
          .map(function (key) {
            var item = request.querystring[key];
            return item.value === '' ? key : key + '=' + item.value;
          })
          .join('&');
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            location: { value: 'https://${local.site_fqdn}' + request.uri + (query ? '?' + query : '') },
          },
        };
      }
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.split('/').pop().includes('.')) {
        request.uri += '/index.html';
      }
      return request;
    }
  JS
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = local.site_fqdn
  default_root_object = "index.html"
  aliases             = [local.site_fqdn, local.www_fqdn]
  web_acl_id          = aws_wafv2_web_acl.site.arn

  origin {
    origin_id                = "s3-site"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-site"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.directory_index.arn
    }
  }

  # OAC without s3:ListBucket makes S3 return 403 for missing keys.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ---------------------------------------------------------------------------
# Free flat-rate pricing plan (no aws provider resource exists yet)
# ---------------------------------------------------------------------------

resource "awscc_pricingplanmanager_subscription" "site" {
  plan_family = "CloudFront"
  plan_tier   = "FREE"
  usage_level = "DEFAULT"

  # Exactly one distribution + one CLOUDFRONT-scope web ACL are required.
  resource_arns = [
    aws_cloudfront_distribution.site.arn,
    aws_wafv2_web_acl.site.arn,
  ]
}

# ---------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------

resource "aws_route53_record" "alias" {
  provider = aws.dns

  for_each = {
    for pair in setproduct([local.site_fqdn, local.www_fqdn], ["A", "AAAA"]) :
    "${pair[0]}-${pair[1]}" => { name = pair[0], type = pair[1] }
  }

  zone_id = data.aws_route53_zone.root.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Only Amazon's CAs may issue certificates for this domain and its subdomains.
# issuewild ";" forbids wildcard issuance.
resource "aws_route53_record" "caa" {
  provider = aws.dns

  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.site_fqdn
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issue \"awstrust.com\"",
    "0 issue \"amazonaws.com\"",
    "0 issuewild \";\"",
  ]
}
