terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "sre-assessment-tfstate-835960997504"
    key            = "sre-assessment/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "sre-assessment-tfstate-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "security" {
  source              = "./modules/security"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  my_ip               = var.my_ip
  private_subnet_cidr = var.private_subnet_cidr
}

module "compute" {
  source            = "./modules/compute"
  project_name      = var.project_name
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  vm1_sg_id         = module.security.vm1_sg_id
  vm2_sg_id         = module.security.vm2_sg_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  public_key_path   = var.public_key_path
}
