# Resources: a security group (with a conditional CIDR) and an EC2 instance.
# Every value comes from a variable — nothing is hardcoded.

locals {
  # Built-in function: lookup(map, key, default)
  recommended_instance_type = lookup(var.instance_type_by_env, var.environment, "t3.micro")
}

resource "aws_security_group" "example" {
  name        = "example-sg-${var.environment}"
  description = "Allow SSH access (CIDR depends on environment)"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # Conditional expression: condition ? true_value : false_value
    cidr_blocks = [
      var.environment == "production" ? var.production_subnet_cidr : var.dev_subnet_cidr
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_instance" "example" {
  ami                    = var.ami_value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.example.id]

  tags = {
    Name        = "terraform-variables-example"
    Environment = var.environment
  }
}
