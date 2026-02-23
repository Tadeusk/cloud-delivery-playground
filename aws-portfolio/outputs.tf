output "aws_bucket_id" {
    value = aws_s3_bucket.website.id
    description = "ID of bucket where is your website"
}

output "cloudfront_url" {
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  description = "Adres Twojej strony w sieci CloudFront"
}