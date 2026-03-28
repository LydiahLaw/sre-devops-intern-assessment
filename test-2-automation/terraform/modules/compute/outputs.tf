output "vm1_public_ip" {
  value = aws_instance.vm1.public_ip
}

output "vm1_private_ip" {
  value = aws_instance.vm1.private_ip
}

output "vm2_private_ip" {
  value = aws_instance.vm2.private_ip
}

output "ami_id" {
  value = data.aws_ami.ubuntu.id
}
