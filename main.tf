# -----------------------------------------------------------
# Data sources
# -----------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  bucket_name = "${var.project_name}-cloudtrail-${local.account_id}"
  trail_arn   = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${var.cloudtrail_trail_name}"
}

# -----------------------------------------------------------
# S3 bucket — CloudTrail log destination
# -----------------------------------------------------------

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = local.bucket_name
  force_destroy = true # Safe for lab; remove in production

  tags = {
    Name        = local.bucket_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------
# Block all public access
# -----------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------
# SSE-S3 encryption (AES-256)
# -----------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------------
# Versioning
# -----------------------------------------------------------

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------
# Bucket policy — allow CloudTrail, deny plain HTTP
# -----------------------------------------------------------

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {

  # 1. CloudTrail checks bucket ACL before it will write to it
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.bucket_name}"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # 2. CloudTrail writes log objects; requires bucket-owner-full-control ACL
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.bucket_name}/AWSLogs/${local.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  # 3. Deny any request not using TLS — defence-in-depth
  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::${local.bucket_name}",
      "arn:aws:s3:::${local.bucket_name}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json

  # Public-access block must exist before a policy can be applied
  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]
}
