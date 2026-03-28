variable "project_name" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "vm1_sg_id" {
  type = string
}

variable "vm2_sg_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
}

variable "public_key_path" {
  description = "Path to your local public key file"
  type        = string
}
