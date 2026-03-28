variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "sre-assessment"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "availability_zone" {
  type    = string
  default = "eu-central-1a"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  description = "Name for the AWS key pair"
  type        = string
  default     = "sre-assessment-key"
}

variable "public_key_path" {
  description = "Path to local SSH public key"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
  sensitive   = true
}
