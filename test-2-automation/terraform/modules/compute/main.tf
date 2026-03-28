# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key pair
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# VM1 — public gateway
resource "aws_instance" "vm1" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.vm1_sg_id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-vm1-gateway"
    Role = "gateway"
  }
}

# VM2 — private app server
resource "aws_instance" "vm2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.vm2_sg_id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = false

  tags = {
    Name = "${var.project_name}-vm2-appserver"
    Role = "app-server"
  }
}
