terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "bootstrap-with-tailwind" {
  bucket = "bootstrap-with-tailwind"
}

resource "aws_s3_bucket_acl" "bootstrap-with-tailwind" {
  acl    = "public-read"
  bucket = aws_s3_bucket.bootstrap-with-tailwind.id
}

resource "aws_s3_bucket_website_configuration" "bootstrap-with-tailwind" {
  bucket = aws_s3_bucket.bootstrap-with-tailwind.bucket

  index_document {
    suffix = "index.html"
  }
}

locals {
  s3_origin_id = "bootstrap-with-tailwind"
  zone_name    = "oliverdavies.uk"
}

resource "aws_cloudfront_origin_access_control" "bootstrap-with-tailwind" {
  name                              = "bootstrap-with-tailwind"
  description                       = "bootstrap-with-tailwind"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "cloudflare_zone" "bootstrap-with-tailwind" {
  name = local.zone_name
}

data "aws_acm_certificate" "bootstrap-with-tailwind" {
  domain   = local.zone_name
  provider = aws.us-east-1
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.bootstrap-with-tailwind.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.bootstrap-with-tailwind.id
    origin_id                = local.s3_origin_id
  }

  comment             = "Bootstrap examples with Tailwind CSS"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true

  aliases = ["bootstrap-with-tailwind.${local.zone_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    default_ttl            = 3600
    max_ttl                = 86400
    min_ttl                = 0
    viewer_protocol_policy = "allow-all"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      locations        = ["US", "CA", "GB"]
      restriction_type = "whitelist"
    }
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.bootstrap-with-tailwind.arn
    ssl_support_method  = "sni-only"
  }
}

resource "cloudflare_record" "bootstrap-with-tailwind" {
  name    = "bootstrap-with-tailwind"
  proxied = false
  ttl     = 0
  type    = "CNAME"
  value   = aws_cloudfront_distribution.s3_distribution.domain_name
  zone_id = data.cloudflare_zone.bootstrap-with-tailwind.id
}
