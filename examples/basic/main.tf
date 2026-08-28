provider "aws" {
  region = "us-west-2"
}

module "spa" {
  source = "../../"

  name        = "ui"
  s3_bucket   = "dev-example-ui"
  namespace   = "dev-example"
  environment = "dev"
}

output "url" {
  value = "https://${module.spa.cloudfront_domain_name}"
}
