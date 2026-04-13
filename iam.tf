# -----------------------------------------------------------
# EC2 trust policy — only EC2 service can assume this role
# -----------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------
# Least-privilege S3 policy — scoped to CloudTrail logs
# bucket only. Read-only: ListBucket + GetObject.
# -----------------------------------------------------------

data "aws_iam_policy_document" "ec2_s3_access" {
  statement {
    sid       = "ListCloudTrailBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    sid       = "ReadCloudTrailObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/*"]
  }
}

# -----------------------------------------------------------
# IAM role
# -----------------------------------------------------------

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-ec2-role"
  description        = "EC2 role for security monitoring lab - SSM access + read CloudTrail logs"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# AWS managed policy — grants SSM Session Manager, Run Command,
# and patch manager permissions required by the SSM agent
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Inline policy — least-privilege read access to CloudTrail bucket
resource "aws_iam_role_policy" "ec2_s3_access" {
  name   = "${var.project_name}-ec2-s3-policy"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_s3_access.json
}

# -----------------------------------------------------------
# Instance profile — wrapper required to attach a role to EC2
# -----------------------------------------------------------

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name        = "${var.project_name}-ec2-profile"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
