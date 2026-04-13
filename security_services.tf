# -----------------------------------------------------------
# GuardDuty
# Note: starts a 30-day free trial on first enable.
# Disable via terraform destroy or targeted destroy during
# teardown before the trial period ends.
# -----------------------------------------------------------

resource "aws_guardduty_detector" "main" {
  enable = true

  # Publish new/updated findings every 15 minutes.
  # Options: FIFTEEN_MINUTES | ONE_HOUR | SIX_HOURS
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = {
    Name        = "${var.project_name}-guardduty"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------
# Security Hub
# Note: starts a 30-day free trial on first enable.
# enable_default_standards = false because we manage all
# standards explicitly below — prevents AWS auto-enabling
# FSBP and causing Terraform state drift.
# -----------------------------------------------------------

resource "aws_securityhub_account" "main" {
  enable_default_standards = false
  auto_enable_controls     = true

  depends_on = [aws_guardduty_detector.main]
}

# -----------------------------------------------------------
# Security Hub standards
# -----------------------------------------------------------

# AWS Foundational Security Best Practices v1.0.0
resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.main]
}

# CIS AWS Foundations Benchmark v1.4.0
resource "aws_securityhub_standards_subscription" "cis_v14" {
  standards_arn = "arn:aws:securityhub:${local.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"

  depends_on = [aws_securityhub_account.main]
}

# -----------------------------------------------------------
# GuardDuty -> Security Hub integration
# GuardDuty findings are forwarded to Security Hub
# automatically once this product subscription is active.
# The integration is native AWS-to-AWS — no configuration
# on the GuardDuty side is required.
# -----------------------------------------------------------

resource "aws_securityhub_product_subscription" "guardduty" {
  product_arn = "arn:aws:securityhub:${local.region}::product/aws/guardduty"

  depends_on = [aws_securityhub_account.main]
}
