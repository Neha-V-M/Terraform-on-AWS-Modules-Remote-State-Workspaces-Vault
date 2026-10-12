#!/usr/bin/env bash
# Installs HashiCorp Vault on Ubuntu from HashiCorp's official apt repository.
# Vault isn't in Ubuntu's default repositories, so we add the vendor repo first.
set -euo pipefail

# 1. Update the package index and install gpg (needed to verify the repo's signing key)
sudo apt-get update -y
sudo apt-get install -y gpg wget lsb-release

# 2. Download HashiCorp's signing key (used to verify packages from their repo)
wget -O - https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 3. Add the official HashiCorp repository to apt sources
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 4. Refresh the package index — always do this after adding a new repository
sudo apt-get update -y

# 5. Install Vault
sudo apt-get install -y vault

# 6. Verify
vault --version
echo
echo "Vault installed. Next: start the dev server in one terminal with:"
echo '  vault server -dev -dev-listen-address="0.0.0.0:8200"'
