mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

variables {
  name        = "ui"
  s3_bucket   = "prod-example-ui"
  namespace   = "prod-example"
  environment = "prod"
}

run "spa_routing_rewrites_errors_to_index" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.default_root_object == "index.html"
    error_message = "default_root_object must be index.html"
  }
  assert {
    condition = alltrue([
      for e in tolist(aws_cloudfront_distribution.this.custom_error_response) :
      e.response_code == 200 && e.response_page_path == "/index.html"
    ])
    error_message = "client-side routing depends on 403 and 404 returning index.html with a 200"
  }
  assert {
    condition = toset([
      for e in tolist(aws_cloudfront_distribution.this.custom_error_response) : e.error_code
    ]) == toset([403, 404])
    error_message = "both 403 (private object) and 404 (unknown key) must be rewritten"
  }
}

run "distribution_uses_oac_over_a_private_origin" {
  command = plan

  assert {
    condition     = aws_cloudfront_origin_access_control.this.signing_protocol == "sigv4"
    error_message = "must use modern OAC (sigv4), not legacy OAI"
  }
  assert {
    condition     = aws_cloudfront_origin_access_control.this.origin_access_control_origin_type == "s3"
    error_message = "OAC origin type must be s3"
  }
  assert {
    condition     = length(aws_cloudfront_distribution.this.origin) == 1
    error_message = "distribution must declare exactly one origin"
  }
  assert {
    condition     = tolist(aws_cloudfront_distribution.this.origin)[0].origin_id == local.s3_origin_id
    error_message = "the origin and the default cache behavior must reference the same origin id"
  }
  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].target_origin_id == local.s3_origin_id
    error_message = "the default cache behavior must target the S3 origin"
  }
}

run "viewers_are_forced_onto_https" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "plain http must be redirected, not served"
  }
}

run "default_domain_uses_the_cloudfront_certificate" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].cloudfront_default_certificate == true
    error_message = "with no dns_names the distribution must fall back to the CloudFront certificate"
  }
  assert {
    condition     = length(tolist(aws_cloudfront_distribution.this.aliases)) == 0
    error_message = "no aliases should be set when dns_names is empty"
  }
}

run "custom_domain_uses_the_supplied_certificate" {
  command = plan

  variables {
    dns_names           = ["app.example.com"]
    acm_certificate_arn = "arn:aws:acm:us-east-1:111111111111:certificate/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  }

  assert {
    condition     = contains(tolist(aws_cloudfront_distribution.this.aliases), "app.example.com")
    error_message = "dns_names must become distribution aliases"
  }
  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].cloudfront_default_certificate == false
    error_message = "a custom domain cannot use the CloudFront default certificate"
  }
  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].acm_certificate_arn == var.acm_certificate_arn
    error_message = "the supplied ACM certificate must be attached"
  }
  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].ssl_support_method == "sni-only"
    error_message = "ssl_support_method must be sni-only"
  }
  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021"
    error_message = "TLS minimum must be 1.2"
  }
}

run "custom_domain_without_a_certificate_fails_the_plan" {
  command = plan

  variables {
    dns_names = ["app.example.com"]
  }

  expect_failures = [aws_cloudfront_distribution.this]
}

run "forwarded_headers_reach_the_cache_key" {
  command = plan

  variables {
    forwarded_headers = ["Origin", "Access-Control-Request-Method"]
  }

  assert {
    condition     = toset(tolist(aws_cloudfront_distribution.this.default_cache_behavior[0].forwarded_values)[0].headers) == toset(var.forwarded_headers)
    error_message = "forwarded_headers must be the exact header set forwarded to the origin"
  }
  assert {
    condition     = tolist(aws_cloudfront_distribution.this.default_cache_behavior[0].forwarded_values)[0].cookies[0].forward == "none"
    error_message = "a static SPA has no session, so cookies must never be forwarded"
  }
}
