locals {
  app_bucket_name = "${var.project_name}-app-${local.account_id}"
}

# -----------------------------------------------------------
# Application data bucket
# -----------------------------------------------------------

resource "aws_s3_bucket" "app" {
  bucket = local.app_bucket_name

  # No force_destroy — treat this like a production bucket

  tags = {
    Name        = local.app_bucket_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------
# Block all public access
# -----------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------
# SSE-S3 encryption (AES-256)
# -----------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

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

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------
# Server access logging — writes to logs/ prefix in this bucket.
# The logging service principal is granted PutObject via the
# bucket policy below, scoped to this account only.
# -----------------------------------------------------------

resource "aws_s3_bucket_logging" "app" {
  bucket        = aws_s3_bucket.app.id
  target_bucket = aws_s3_bucket.app.id
  target_prefix = "logs/"
}

# -----------------------------------------------------------
# Bucket policy
# -----------------------------------------------------------

data "aws_iam_policy_document" "app_bucket_policy" {

  # 1. Allow S3 log delivery service to write access logs to
  #    the logs/ prefix. Scoped to this account to prevent
  #    cross-account log injection.
  statement {
    sid    = "S3LogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.app_bucket_name}/logs/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  # 2. Deny any request not using TLS — HTTPS only.
  #    Principal "*" covers all IAM principals. The S3 log
  #    delivery service always uses HTTPS so it is not blocked.
  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::${local.app_bucket_name}",
      "arn:aws:s3:::${local.app_bucket_name}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.app]
}
