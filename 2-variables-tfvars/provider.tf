# Provider configuration.
# Credentials come from the AWS CLI (`aws configure`) — nothing sensitive is hardcoded here.

provider "aws" {
  region = var.region
}
