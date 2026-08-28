# terraform-aws-cloudfront-spa

Hosts a single-page application on S3 behind CloudFront. The bucket stays private and CloudFront reads it through an Origin Access Control, so the only public entry point is the distribution.

## What it creates

- A private S3 bucket with versioning, all four public-access blocks, and a policy that grants `s3:GetObject` to the CloudFront service principal for this distribution only
- A CloudFront distribution with an Origin Access Control, HTTPS redirect, and gzip compression
- 403 and 404 rewrites to `/index.html` with a 200 status, which is what makes client-side routing work on a static origin
- An optional CORS configuration on the bucket

## Usage

The CloudFront default domain, which needs no certificate:

```hcl
module "spa" {
  source = "github.com/synapsestudios/terraform-aws-cloudfront-spa"

  name        = "ui"
  s3_bucket   = "dev-example-ui"
  namespace   = "dev-example"
  environment = "dev"
}
```

A custom domain. CloudFront only accepts certificates issued in `us-east-1`, so the certificate has to come from a provider aliased to that region:

```hcl
module "spa" {
  source = "github.com/synapsestudios/terraform-aws-cloudfront-spa"

  name        = "ui"
  s3_bucket   = "prod-example-ui"
  namespace   = "prod-example"
  environment = "prod"

  dns_names           = ["app.example.com"]
  acm_certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}
```

Setting `dns_names` without `acm_certificate_arn` fails at plan time rather than at apply. `examples/custom-domain` shows the certificate, its DNS validation, and the Route 53 alias record.

The module creates the bucket. Pick an `s3_bucket` name that is globally unique and does not already exist.

## Inputs

| Name | Description | Type | Default |
| --- | --- | --- | --- |
| `name` | Name of this deployment, such as `ui` or `admin-ui` | `string` | required |
| `s3_bucket` | Name of the bucket to create | `string` | required |
| `namespace` | Prefix applied to resource names | `string` | required |
| `environment` | Environment name, written to the `Environment` tag | `string` | required |
| `dns_names` | Aliases for the distribution. Empty uses the CloudFront default domain. | `list(string)` | `[]` |
| `acm_certificate_arn` | ARN of a `us-east-1` certificate. Required when `dns_names` is set. | `string` | `null` |
| `web_acl_id` | ID of a WAF web ACL to associate | `string` | `null` |
| `is_ipv6_enabled` | Whether the distribution answers over IPv6 | `bool` | `true` |
| `forwarded_headers` | Request headers forwarded to the origin and included in the cache key | `list(string)` | `["Origin"]` |
| `cors_rule` | CORS rules for the bucket. Empty creates no CORS configuration. | `list(object)` | `[]` |
| `tags` | Tags applied to the bucket and the distribution | `map(string)` | `{}` |

## Outputs

| Name | Description |
| --- | --- |
| `cloudfront_id` | Distribution ID, which a deploy step uses to create invalidations |
| `cloudfront_arn` | Distribution ARN |
| `cloudfront_domain_name` | Distribution domain name, such as `d111111abcdef8.cloudfront.net` |
| `cloudfront_hosted_zone_id` | Zone ID for a Route 53 alias record pointing at the distribution |
| `bucket_name` | Bucket name, which a deploy step syncs build output into |
| `bucket_arn` | Bucket ARN |
| `bucket_regional_domain_name` | Regional domain name of the bucket |

## Defaults worth knowing

`price_class` is `PriceClass_100`, covering North America and Europe. Raise it in the module if you need the other edge locations.

Cache TTLs are 0 minimum, 3600 default, and 86400 maximum. Hashed asset filenames plus an invalidation on `/index.html` after each deploy is the usual pairing.

`wait_for_deployment` is `false`, so an apply returns before CloudFront finishes propagating. Expect a few minutes before a change is live at every edge.

Cookies are never forwarded to the origin.

## Known limits

The distribution uses the legacy `forwarded_values` block instead of a cache policy. AWS marks that block deprecated in favor of `cache_policy_id` and `origin_request_policy_id`. It still works, and moving to a cache policy would change the `forwarded_headers` input.

The bucket sets `object_ownership` to `BucketOwnerPreferred` and applies a private ACL. Current AWS practice is `BucketOwnerEnforced`, which disables ACLs entirely. Nothing here needs ACLs.

The bucket has no explicit server-side encryption configuration, so it takes the S3 account default.

## Development

```sh
terraform init -backend=false
terraform test
```

Tests in `tests/` run against a mock AWS provider, so they need no credentials and cost nothing.

## License

MIT. See [LICENSE](LICENSE).
