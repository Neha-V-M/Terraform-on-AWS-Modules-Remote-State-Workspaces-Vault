# Reusable EC2 instance module — same pattern as folder 3/.
# No hardcoded values, no provider block, no tfvars. Inherits the provider
# configuration from whoever calls it.

resource "aws_instance" "example" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = {
    Name       = "terraform-workspaces-demo"
    Workspace  = terraform.workspace
  }
}
