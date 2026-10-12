variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_value" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}

# --- Vault connection ---

variable "vault_address" {
  description = "Vault server URL including scheme and port, e.g. http://<ip>:8200"
  type        = string
}

variable "vault_role_id" {
  description = "AppRole Role ID for the 'terraform' role"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole Secret ID for the 'terraform' role"
  type        = string
  sensitive   = true
}

variable "vault_kv_mount" {
  description = "Mount path of the KV secrets engine"
  type        = string
  default     = "kv"
}

variable "vault_secret_name" {
  description = "Name of the secret stored in Vault"
  type        = string
  default     = "test-secret"
}

# Only used by the optional S3 example in main.tf
variable "bucket_suffix" {
  description = "Unique suffix to make the optional S3 bucket name globally unique"
  type        = string
  default     = "change-me"
}
