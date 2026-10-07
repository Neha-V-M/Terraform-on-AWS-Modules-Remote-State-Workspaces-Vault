output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.example.id
}

output "public_ip" {
  description = "Public IP address of the created EC2 instance"
  value       = aws_instance.example.public_ip
}
