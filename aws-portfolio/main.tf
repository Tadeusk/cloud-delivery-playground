resource "aws_s3_bucket" "website" {
    bucket = "portfolio-${var.domain_name}"
    tags = {
        Name = var.project_name
    }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document { suffix = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "index" {
    bucket          = aws_s3_bucket.website.id
    key             = "index.html"
    source          = "website/index.html"
    content_type    = "text/html"
    source_hash  = filemd5("website/index.html")
    }

resource "aws_s3_object" "styles" {
    bucket          = aws_s3_bucket.website.id
    key             = "styles.css"
    source          = "website/styles.css"
    content_type    = "text/css"
    source_hash  = filemd5("website/styles.css")
}

# The main part. (Cloudfront)
resource "aws_cloudfront_origin_access_control" "default" {
    name                        = "s3-oac-${var.domain_name}"
    origin_access_control_origin_type  = "s3"
    signing_behavior            = "always"
    signing_protocol            = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = "S3-${aws_s3_bucket.website.bucket}"
  }
    enabled = true
    is_ipv6_enabled = true
    default_root_object = "index.html"
    aliases = [var.domain_name]
    default_cache_behavior {
        allowed_methods     = ["GET", "HEAD"]
        cached_methods      = ["GET", "HEAD"]
        target_origin_id    = "S3-${aws_s3_bucket.website.bucket}"
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy  = "redirect-to-https" #auto https 
        min_ttl                 = 0
        default_ttl             = 3600
        max_ttl                 = 86400
    }
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }
    viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
    depends_on = [aws_s3_bucket.website]
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront"  {
    bucket = aws_s3_bucket.website.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
         }
        }
      ]
    })
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1 # CloudFront wymaga certyfikatów tylko z Virginia!
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "null_resource" "invalidate_cache" {
  triggers = {
    index_hash  = aws_s3_object.index.etag
    styles_hash = aws_s3_object.styles.etag
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.s3_distribution.id} --paths '/*'"
  }

  depends_on = [
    aws_s3_object.index,
    aws_s3_object.styles,
    aws_cloudfront_distribution.s3_distribution
  ]
}