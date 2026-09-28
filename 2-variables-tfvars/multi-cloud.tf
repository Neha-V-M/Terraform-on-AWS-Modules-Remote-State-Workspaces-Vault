# REFERENCE EXAMPLE — hybrid cloud: AWS + Azure in one project.
# Copy into an empty scratch folder to try it; it is not applied from the parent folder.
# Always confirm exact provider/resource names and arguments in the official docs.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

# AWS — authenticates via the AWS CLI credentials already configured
provider "aws" {
  region = "us-east-1"
}

# Azure — service principal authentication.
# Prefer environment variables (ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID,
# ARM_CLIENT_SECRET, ARM_TENANT_ID) over hardcoding these values.
provider "azurerm" {
  features {}

  subscription_id = "<subscription-id>"
  client_id       = "<client-id>"
  client_secret   = "<client-secret>"
  tenant_id       = "<tenant-id>"
}

# Virtual machine on AWS
resource "aws_instance" "aws_vm" {
  ami           = "<ami-id>"
  instance_type = "t2.micro"
}

# Virtual machine on Azure — resource type differs from AWS.
# See the azurerm provider docs for a complete example including the
# required resource group, network interface, and OS settings.
# resource "azurerm_linux_virtual_machine" "azure_vm" { ... }
