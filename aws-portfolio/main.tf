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

resource "aws_dynamodb_table" "portfolio_table" {
  name           = "ktad-portfolio-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "PK"

  attribute {
    name = "PK"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "PortfolioLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- LAMBDA FUNCTION ---
resource "aws_lambda_function" "portfolio_counter" {
  filename      = "lambda-functions/function.zip"
  function_name = "portfolio-counter"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11" 

  source_code_hash = filebase64sha256("lambda-functions/function.zip")
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.portfolio_counter.function_name
  principal     = "apigateway.amazonaws.com"
  
  # Opcjonalnie do konkretnego API:
  # source_arn = "${aws_api_gateway_rest_api.portfolio_api.execution_arn}/*/*"
}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  parent_id   = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  path_part   = "prod" 
}

resource "aws_api_gateway_rest_api" "portfolio_api" {
  name        = "PortfolioAPI"
  description = "API for Portfolio Counter"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  resource_id   = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.portfolio_api.id
  resource_id             = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.portfolio_counter.invoke_arn
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  resource_id   = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.portfolio_api.id
  resource_id             = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.portfolio_counter.invoke_arn
}

# 1. Definicja metody OPTIONS
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  resource_id   = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# 2. Odpowiedź dla OPTIONS
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.portfolio_api.id
  resource_id             = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method             = aws_api_gateway_method.options.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  resource_id = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id
  resource_id = aws_api_gateway_rest_api.portfolio_api.root_resource_id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_integration]
}

resource "aws_api_gateway_deployment" "portfolio_deploy" {
  rest_api_id = aws_api_gateway_rest_api.portfolio_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.options.id,
      aws_api_gateway_integration.options_integration.id,
      aws_api_gateway_integration_response.options_integration_response.id,
      aws_api_gateway_method.get.id,
      aws_api_gateway_method.post.id    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.portfolio_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.portfolio_api.id
  stage_name    = "prod"
}