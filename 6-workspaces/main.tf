provider "aws" {
  region = var.region
}

# -----------------------------------------------------------------------------
# Resolve the instance type for the CURRENTLY ACTIVE workspace.
# terraform.workspace is a built-in value — no tfvars editing needed to
# switch between dev / stage / prod.
# -----------------------------------------------------------------------------
locals {
  resolved_instance_type = lookup(var.instance_type, terraform.workspace, "t2.micro")
}

module "ec2_instance" {
  source = "./modules/ec2_instance"

  ami           = var.ami_value
  instance_type = local.resolved_instance_type
  subnet_id     = var.subnet_id
}

output "active_workspace" {
  description = "Which workspace this apply ran against"
  value       = terraform.workspace
}

output "resolved_instance_type" {
  description = "The instance_type lookup() resolved for the active workspace"
  value       = local.resolved_instance_type
}

output "module_instance_public_ip" {
  description = "Public IP reported back by the ec2_instance module"
  value       = module.ec2_instance.public_ip
}
