variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "security-monitoring-lab"
}

variable "environment" {
  description = "Environment tag applied to all resources"
  type        = string
  default     = "lab"
}

variable "cloudtrail_trail_name" {
  description = "Name of the existing CloudTrail multi-region trail"
  type        = string
  default     = "lab-audit-trail"
}
