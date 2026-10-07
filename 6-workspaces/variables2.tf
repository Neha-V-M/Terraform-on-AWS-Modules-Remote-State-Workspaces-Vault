# Inputs this module expects. The caller resolves the right instance_type
# per workspace (via lookup()) BEFORE passing it in here — this module just
# takes a plain string, it doesn't know anything about workspaces itself.

variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type, already resolved by the caller for the current workspace"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}
