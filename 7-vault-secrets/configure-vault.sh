#!/usr/bin/env bash
# Configures a freshly started Vault DEV server for the Terraform integration.
#
# Prerequisites (second terminal, dev server running in the first):
#   export VAULT_ADDR='http://127.0.0.1:8200'
#   export VAULT_TOKEN='<root-token printed by the dev server>'
#
# A Vault dev server keeps nothing across restarts — re-run this script
# after every restart, then update terraform.tfvars with the new IDs.
set -euo pipefail

: "${VAULT_ADDR:?Set VAULT_ADDR first, e.g. export VAULT_ADDR='http://127.0.0.1:8200'}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN to the root token printed by the dev server}"

MOUNT="kv"
SECRET_NAME="test-secret"
POLICY_NAME="terraform"
ROLE_NAME="terraform"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 1. Enabling KV v2 secrets engine at path '${MOUNT}'"
vault secrets enable -path="${MOUNT}" kv-v2 || echo "    (already enabled, continuing)"

echo "==> 2. Creating example secret '${MOUNT}/${SECRET_NAME}'"
vault kv put "${MOUNT}/${SECRET_NAME}" username=abhishek

echo "==> 3. Writing policy '${POLICY_NAME}'"
vault policy write "${POLICY_NAME}" "${SCRIPT_DIR}/terraform-policy.hcl"

echo "==> 4. Enabling the AppRole auth method"
vault auth enable approle || echo "    (already enabled, continuing)"

echo "==> 5. Creating AppRole '${ROLE_NAME}' and attaching the policy"
# token_policies is the key parameter: it attaches the policy to the role.
# The TTL / use-limit settings below are DEMO values chosen for stability:
#   secret_id_ttl=0 and secret_id_num_uses=0 mean the Secret ID never expires
#   and can be used unlimited times. Do NOT use these in production —
#   review every parameter against the official Vault docs.
vault write "auth/approle/role/${ROLE_NAME}" \
  token_policies="${POLICY_NAME}" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0 \
  secret_id_num_uses=0

echo "==> 6. Fetching Role ID and Secret ID"
ROLE_ID="$(vault read -field=role_id "auth/approle/role/${ROLE_NAME}/role-id")"
SECRET_ID="$(vault write -f -field=secret_id "auth/approle/role/${ROLE_NAME}/secret-id")"

echo
echo "================================================================"
echo " Copy these into terraform.tfvars (keep them PRIVATE — they are"
echo " the Vault equivalent of AWS access keys):"
echo
echo "   vault_role_id   = \"${ROLE_ID}\""
echo "   vault_secret_id = \"${SECRET_ID}\""
echo "================================================================"
