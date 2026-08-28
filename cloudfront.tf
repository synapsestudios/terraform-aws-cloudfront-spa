locals {
  s3_origin_id = "s3-${var.name}-${var.namespace}"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.namespace}-${var.name}-oac"
  description                       = "OAC for ${var.name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = var.is_ipv6_enabled
  wait_for_deployment = false
  comment             = "${var.namespace}-${var.name}"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = var.dns_names
  web_acl_id          = var.web_acl_id

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      headers      = var.forwarded_headers

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = length(var.dns_names) == 0
    acm_certificate_arn            = length(var.dns_names) > 0 ? var.acm_certificate_arn : null
    ssl_support_method             = length(var.dns_names) > 0 ? "sni-only" : null
    minimum_protocol_version       = length(var.dns_names) > 0 ? "TLSv1.2_2021" : null
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.namespace}-${var.name}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  lifecycle {
    precondition {
      condition     = length(var.dns_names) == 0 || var.acm_certificate_arn != null
      error_message = "acm_certificate_arn is required when dns_names is set: CloudFront rejects an alias without a matching certificate."
    }
  }
}
