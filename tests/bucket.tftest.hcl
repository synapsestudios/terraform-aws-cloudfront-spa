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

run "bucket_blocks_all_public_access" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls must be true"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy must be true"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls must be true"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets must be true"
  }
  assert {
    condition     = aws_s3_bucket_acl.this.acl == "private"
    error_message = "bucket ACL must be private: CloudFront reads through OAC, never anonymously"
  }
}

run "bucket_policy_restricts_to_this_distribution" {
  command = plan

  assert {
    condition = anytrue([
      for p in data.aws_iam_policy_document.cloudfront_oac_access.statement[0].principals :
      contains(p.identifiers, "cloudfront.amazonaws.com")
    ])
    error_message = "bucket policy must grant access only to the CloudFront service principal"
  }
  assert {
    condition     = data.aws_iam_policy_document.cloudfront_oac_access.statement[0].actions == toset(["s3:GetObject"])
    error_message = "bucket policy must grant s3:GetObject and nothing else"
  }
  assert {
    condition = anytrue([
      for c in data.aws_iam_policy_document.cloudfront_oac_access.statement[0].condition :
      c.test == "StringEquals" && c.variable == "AWS:SourceArn"
    ])
    error_message = "bucket policy must pin access to THIS distribution via StringEquals on AWS:SourceArn"
  }
}

run "bucket_versioning_is_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must be enabled so a bad deploy can be rolled back"
  }
}

run "cors_is_absent_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 0
    error_message = "no CORS configuration should be created when cors_rule is empty"
  }
}

run "cors_is_created_when_rules_are_supplied" {
  command = plan

  variables {
    cors_rule = [{
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["https://app.example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }]
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 1
    error_message = "a CORS configuration must be created when cors_rule is non-empty"
  }
  assert {
    condition = anytrue([
      for r in aws_s3_bucket_cors_configuration.this[0].cors_rule :
      contains(r.allowed_origins, "https://app.example.com")
    ])
    error_message = "supplied CORS rules must reach the bucket configuration"
  }
}
