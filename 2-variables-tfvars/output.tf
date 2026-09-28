# Output values — printed after `terraform apply` completes.
# Format: <resource_type>.<resource_name>.<attribute>

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.example.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.example.id
}

output "ssh_cidr_in_use" {
  description = "Which CIDR the conditional expression selected for SSH"
  value       = var.environment == "production" ? var.production_subnet_cidr : var.dev_subnet_cidr
}

# Built-in function demos
output "recommended_instance_type" {
  description = "lookup() result for the current environment"
  value       = local.recommended_instance_type
}

output "allowed_ssh_cidr_count" {
  description = "length() of the allowed CIDR list"
  value       = length(var.allowed_ssh_cidrs)
}
