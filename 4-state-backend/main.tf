provider "aws" {
  region = var.region
}

# -----------------------------------------------------------------------------
# The actual workload — an EC2 instance, same pattern as previous folders.
# -----------------------------------------------------------------------------
resource "aws_instance" "example" {
  ami           = var.ami_value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  tags = {
    Name = "terraform-state-demo"
  }
}

# -----------------------------------------------------------------------------
# Backend resources — the S3 bucket and DynamoDB table that backend.tf will
# later point to. These must exist BEFORE backend.tf is uncommented.
# See README.md "Correct Order of Operations" for the full sequence.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of a bucket holding your state file.
  lifecycle {
    prevent_destroy = false # set to true once this is a real/shared backend
  }

  tags = {
    Name    = "terraform-remote-state"
    Purpose = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled" # keeps state history, lets you roll back a bad apply
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform_lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Purpose = "terraform-state-locking"
  }
}
