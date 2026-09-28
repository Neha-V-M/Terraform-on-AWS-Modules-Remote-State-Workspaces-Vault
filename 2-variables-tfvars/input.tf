# Input variable declarations.
# Actual values are supplied through terraform.tfvars (see terraform.tfvars.example).

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_value" {
  description = "AMI ID for the EC2 instance"
  type        = string
  # No default on purpose — must be supplied via terraform.tfvars
}

variable "instance_type" {
  description = "The EC2 instance type to use"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the security group (leave null to use the default VPC)"
  type        = string
  default     = null
}

# --- Used by the conditional expression in main.tf ---

variable "environment" {
  description = "Deployment environment: dev or production"
  type        = string
  default     = "dev"
}

variable "production_subnet_cidr" {
  description = "CIDR allowed to SSH when environment is production"
  type        = string
  default     = "10.0.1.0/24"
}

variable "dev_subnet_cidr" {
  description = "CIDR allowed to SSH when environment is dev"
  type        = string
  default     = "10.0.2.0/24"
}

# --- Used to demonstrate built-in functions (lookup / length) ---

variable "instance_type_by_env" {
  description = "Instance type to use per environment"
  type        = map(string)
  default = {
    dev        = "t2.micro"
    staging    = "t2.small"
    production = "t2.medium"
  }
}

variable "allowed_ssh_cidrs" {
  description = "Extra CIDRs (informational — used to demonstrate length())"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
