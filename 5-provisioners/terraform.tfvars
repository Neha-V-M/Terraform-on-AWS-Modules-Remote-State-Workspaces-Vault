# Copy this file to terraform.tfvars and fill in your own values.
# terraform.tfvars is git-ignored — never commit real values.
#
# Before running, also generate a local key pair in this folder:
#   ssh-keygen -t rsa -f ./terraform-key -N ""
# (terraform-key and terraform-key.pub are git-ignored too — never commit private keys)

region            = "us-east-1"
ami_value         = "<ubuntu-ami-id>"   # must be an Ubuntu AMI
instance_type     = "t2.micro"
vpc_cidr          = "10.0.0.0/16"
subnet_cidr       = "10.0.1.0/24"
availability_zone = "us-east-1a"
