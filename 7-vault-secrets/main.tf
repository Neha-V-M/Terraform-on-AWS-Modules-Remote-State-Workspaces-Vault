terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}

# AWS provider — needed because the Vault secret is used on an AWS resource.
provider "aws" {
  region = var.region
}

# Vault provider — authenticates with AppRole (Role ID + Secret ID).
provider "vault" {
  address          = var.vault_address # must include http:// and the port, e.g. http://1.2.3.4:8200
  skip_child_token = true              # recommended by HashiCorp for token-based auth

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# -----------------------------------------------------------------------------
# READ a secret from Vault. `data` = read, `resource` = create.
# This single block is also the first real test of Vault authentication —
# `terraform init` alone does NOT prove auth works.
# -----------------------------------------------------------------------------
data "vault_kv_secret_v2" "example" {
  mount = var.vault_kv_mount   # path chosen when the KV engine was enabled
  name  = var.vault_secret_name
}

# -----------------------------------------------------------------------------
# USE the secret on an AWS resource.
# Indexing with ["username"] returns just that key's value; without it you'd
# get the whole key-value map.
# -----------------------------------------------------------------------------
resource "aws_instance" "example" {
  ami           = var.ami_value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = {
    Name   = "terraform-vault-demo"
    secret = data.vault_kv_secret_v2.example.data["username"]
  }
}

# -----------------------------------------------------------------------------
# OPTIONAL: use the same secret as an S3 bucket name.
# Bucket names must be GLOBALLY unique across AWS, so combine the secret with
# something unique. Uncomment to try it.
# -----------------------------------------------------------------------------
# resource "aws_s3_bucket" "from_secret" {
#   bucket = "${data.vault_kv_secret_v2.example.data["username"]}-tf-vault-demo-${var.bucket_suffix}"
# }
