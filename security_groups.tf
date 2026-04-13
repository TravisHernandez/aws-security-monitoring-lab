# -----------------------------------------------------------
# EC2 Security Group
# No inbound rules — SSM Session Manager requires no open
# inbound ports. Outbound HTTPS (443) is required for the
# SSM agent to reach SSM, EC2Messages, and SSMMessages
# endpoints (either public or via VPC endpoints).
# -----------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 instance SG - no inbound SSH, SSM access only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS outbound for SSM agent endpoint communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
