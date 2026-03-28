variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "my_ip" {
  description = "Your public IP for SSH access to VM1"
  type        = string
  sensitive   = true
}

variable "private_subnet_cidr" {
  type = string
}
