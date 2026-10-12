# Vault policy attached to the "terraform" AppRole.
# Conceptually the same as an IAM policy attached to an IAM role in AWS.
#
# The KV v2 engine stores secret data under <mount>/data/... and metadata
# under <mount>/metadata/..., so both paths need to be granted.
# Read-only is enough — Terraform only reads the secret in this folder.

path "kv/data/*" {
  capabilities = ["read", "list"]
}

path "kv/metadata/*" {
  capabilities = ["read", "list"]
}

# If you chose a different mount name (e.g. "secret"), duplicate the blocks
# above with that name. Keep this list as narrow as you can in real use.
