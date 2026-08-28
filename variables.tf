variable "name" {
  type        = string
  description = "Name of this deployment (e.g., 'ui', 'admin-ui')"
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket name that will be created for this deployment"
}

variable "environment" {
  type        = string
  description = "Name of environment (e.g., 'prod', 'dev', 'staging')"
}

variable "namespace" {
  type        = string
  description = "Prefix applied to resource names. Generally follows DNS naming convention (e.g., 'prod-example')"
}

variable "dns_names" {
  type        = list(string)
  description = "DNS names to associate with this deployment (e.g., ['app.example.com']). Leave empty to use the CloudFront default domain."
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "ARN of an ACM certificate in us-east-1. Required when dns_names is set."
  default     = null
}

variable "web_acl_id" {
  type        = string
  description = "ID of an AWS WAF web ACL to associate with the distribution"
  default     = null
}

variable "is_ipv6_enabled" {
  type        = bool
  description = "Whether IPv6 is enabled for the distribution"
  default     = true
}

variable "forwarded_headers" {
  type        = list(string)
  description = "Request headers CloudFront forwards to the origin and includes in the cache key"
  default     = ["Origin"]
}

variable "cors_rule" {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  }))
  description = "CORS rules to apply to the S3 bucket. No CORS configuration is created when empty."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to the created resources"
  default     = {}
}
