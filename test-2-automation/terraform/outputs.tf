output "vm1_public_ip" {
  description = "Public IP of gateway VM"
  value       = module.compute.vm1_public_ip
}

output "vm1_private_ip" {
  description = "Private IP of gateway VM"
  value       = module.compute.vm1_private_ip
}

output "vm2_private_ip" {
  description = "Private IP of app server VM"
  value       = module.compute.vm2_private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
