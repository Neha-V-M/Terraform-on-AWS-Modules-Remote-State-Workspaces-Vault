variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_value" {
  description = "AMI ID for the EC2 instance (same AMI used across all workspaces here)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in (same subnet used across all workspaces here)"
  type        = string
}

# Keyed by workspace name. terraform.workspace + lookup() picks the right
# value automatically — no need to edit this per environment.
variable "instance_type" {
  description = "Instance type per environment/workspace"
  type        = map(string)
  default = {
    dev   = "t3.micro"
    stage = "t2.medium"
    prod  = "t2.xlarge"
  }
}
