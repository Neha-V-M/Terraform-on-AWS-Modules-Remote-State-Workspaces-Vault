# Copy this file to terraform.tfvars and fill in your own values.
# terraform.tfvars is git-ignored — never commit real values.

region        = "us-east-1"
ami_value     = "<ami-id>"
instance_type = "t3.micro"
subnet_id     = "<subnet-id>"
key_name      = "<key-pair-name>"

# Optional: set if your subnet is not in the default VPC
# vpc_id = "<vpc-id>"

# Conditional expression inputs
environment            = "dev"          # try "production" to see the CIDR switch
production_subnet_cidr = "10.0.1.0/24"
dev_subnet_cidr        = "10.0.2.0/24"
