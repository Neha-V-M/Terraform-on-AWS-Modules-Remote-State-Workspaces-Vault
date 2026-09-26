# -----------------------------------------------------------------------------
# 1. Introduction to IaC — First EC2 Deployment
#
# Minimal Terraform project: one provider block, one resource block.
# Replace the placeholder values 
# -----------------------------------------------------------------------------

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "example" {
  ami           = "<ami-id>"          # e.g. an Ubuntu AMI ID from the EC2 console
  instance_type = "t3.micro"          # covered under the AWS free tier
  subnet_id     = "<subnet-id>"       # from VPC console -> Subnets
  key_name      = "<key-pair-name>"   # from EC2 console -> Key Pairs

  tags = {
    Name = "terraform-example-1"
  }
}
