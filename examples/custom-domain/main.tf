provider "aws" {
  region = "us-west-2"
}

# CloudFront only accepts certificates issued in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "domain_name" {
  type    = string
  default = "app.example.com"
}

variable "route53_zone_id" {
  type = string
}

resource "aws_acm_certificate" "this" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for option in aws_acm_certificate.this.domain_validation_options :
    option.domain_name => option
  }

  zone_id = var.route53_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

module "spa" {
  source = "../../"

  name        = "ui"
  s3_bucket   = "prod-example-ui"
  namespace   = "prod-example"
  environment = "prod"

  dns_names           = [var.domain_name]
  acm_certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}

resource "aws_route53_record" "alias" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.spa.cloudfront_domain_name
    zone_id                = module.spa.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
