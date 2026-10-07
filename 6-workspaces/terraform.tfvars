# Copy this file to terraform.tfvars and fill in your own values.
# terraform.tfvars is git-ignored — never commit real values.
#
# Note: instance_type is NOT set here on purpose — it's resolved automatically
# per workspace via terraform.workspace + lookup() in main.tf (see variables.tf
# for the default map). Only override it here if you want to change those
# per-environment defaults.

region    = "us-east-1"
ami_value = "<ami-id>"
subnet_id = "<subnet-id>"

# Optional override of the per-environment instance types:
# instance_type = {
#   dev   = "t3.micro"
#   stage = "t2.medium"
#   prod  = "t2.xlarge"
# }
