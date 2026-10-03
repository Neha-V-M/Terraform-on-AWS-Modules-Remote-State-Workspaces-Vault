# Copy this file to terraform.tfvars and fill in your own values.
# terraform.tfvars is git-ignored — never commit real values.

region        = "us-east-1"
ami_value     = "<ami-id>"
instance_type = "t2.micro"
subnet_id     = "<subnet-id>"
key_name      = "<key-pair-name>"

# Must be globally unique across all of AWS — e.g. "<yourname>-tf-state-demo"
state_bucket_name = "<your-unique-bucket-name>"
