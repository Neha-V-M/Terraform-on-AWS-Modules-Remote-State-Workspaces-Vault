# Consuming project — represents "team XYZ" calling a reusable module.
# Notice how short this is compared to writing the EC2 logic from scratch:
# only a provider block, variable declarations (see variables.tf), and a module block.

provider "aws" {
  region = "us-east-1"
}

module "ec2_instance" {
  source = "./modules/ec2_instance"

  ami_value            = var.ami_value
  instance_type_value  = var.instance_type
  subnet_id_value      = var.subnet_id
  key_name_value       = var.key_name
  instance_name        = "terraform-modules-demo"
}

output "module_instance_public_ip" {
  description = "Public IP reported back by the ec2_instance module"
  value       = module.ec2_instance.public_ip
}
