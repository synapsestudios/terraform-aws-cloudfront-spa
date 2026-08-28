output "cloudfront_id" {
  description = "Identifier of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution (e.g., d111111abcdef8.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Route 53 zone ID to use when pointing an alias record at the distribution"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
