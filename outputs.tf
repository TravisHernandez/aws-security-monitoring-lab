output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket receiving CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the S3 bucket receiving CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "account_id" {
  description = "AWS Account ID derived at plan time"
  value       = data.aws_caller_identity.current.account_id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 instance security group"
  value       = aws_security_group.ec2.id
}

output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "securityhub_arn" {
  description = "Security Hub account ARN"
  value       = aws_securityhub_account.main.id
}

output "app_bucket_name" {
  description = "Name of the application S3 bucket"
  value       = aws_s3_bucket.app.id
}

output "app_bucket_arn" {
  description = "ARN of the application S3 bucket"
  value       = aws_s3_bucket.app.arn
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "ec2_ami_id" {
  description = "AMI ID resolved at apply time"
  value       = nonsensitive(aws_instance.main.ami)
}
