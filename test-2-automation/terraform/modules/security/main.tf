# Security group for VM1 (gateway/public)
resource "aws_security_group" "vm1_sg" {
  name        = "${var.project_name}-vm1-sg"
  description = "Security group for public gateway VM"
  vpc_id      = var.vpc_id

  # SSH from your IP only
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  # HTTP from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vm1-sg"
  }
}

# Security group for VM2 (app server/private)
resource "aws_security_group" "vm2_sg" {
  name        = "${var.project_name}-vm2-sg"
  description = "Security group for private app server VM"
  vpc_id      = var.vpc_id

  # All traffic from private subnet only (VM1 can reach VM2)
  ingress {
    description = "All traffic from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  # All traffic from VM1 security group
  ingress {
    description     = "All traffic from VM1"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.vm1_sg.id]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vm2-sg"
  }
}
