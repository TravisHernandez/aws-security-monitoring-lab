# -----------------------------------------------------------
# Latest Amazon Linux 2023 AMI — resolved via SSM Parameter
# Store so the ID never needs to be hardcoded or manually
# updated. AWS keeps this pointer current.
# -----------------------------------------------------------

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------------
# EC2 instance
# -----------------------------------------------------------

resource "aws_instance" "main" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # No key pair — access exclusively via SSM Session Manager
  key_name = null

  # Detailed CloudWatch monitoring (1-minute metric resolution)
  monitoring = false

  # AL2023 ships with the SSM agent pre-installed and enabled.
  # No user_data needed for SSM connectivity.

  tags = {
    Name        = "${var.project_name}-instance"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
