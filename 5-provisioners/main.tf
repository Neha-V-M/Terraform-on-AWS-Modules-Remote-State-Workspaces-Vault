provider "aws" {
  region = var.region
}

# -----------------------------------------------------------------------------
# Key pair — the public half of a locally generated SSH key.
# Generate it first: ssh-keygen -t rsa -f ./terraform-key -N ""
# -----------------------------------------------------------------------------
resource "aws_key_pair" "example" {
  key_name   = "terraform-provisioners-key"
  public_key = file("${path.module}/terraform-key.pub")
}

# -----------------------------------------------------------------------------
# Networking — VPC, public subnet, Internet Gateway, route table
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-provisioners-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-provisioners-public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-provisioners-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform-provisioners-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Security group — port 80 for the app, port 22 for SSH troubleshooting
# -----------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "terraform-provisioners-sg"
  description = "Allow HTTP (80) and SSH (22)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "App traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH (troubleshooting)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (apt, pip, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-provisioners-sg"
  }
}

# -----------------------------------------------------------------------------
# EC2 instance + zero-touch app deployment via provisioners
# -----------------------------------------------------------------------------
resource "aws_instance" "app" {
  ami                    = var.ami_value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name = "terraform-provisioners-app"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu" # matches an Ubuntu AMI
    private_key = file("${path.module}/terraform-key")
    host        = self.public_ip
  }

  # Copy the Flask app onto the instance
  provisioner "file" {
    source      = "${path.module}/app.py"
    destination = "/home/ubuntu/app.py"
  }

  # Install dependencies and run the app.
  # `nohup ... &` fully detaches the process so it survives the SSH session ending.
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y python3-pip",
      "pip3 install flask",
      "cd /home/ubuntu && nohup python3 app.py > flask.log 2>&1 &",
      "sleep 2",
      "sudo ss -ltnp | grep :80 || echo 'WARNING: app does not appear to be listening on port 80'"
    ]
  }
}
