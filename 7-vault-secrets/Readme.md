# 7. Secrets Management — Integrating Terraform With HashiCorp Vault

Every DevOps engineer handles sensitive data: passwords, API tokens, certificates. This module shows
how to keep those values **out of your Terraform code** by storing them in HashiCorp Vault and reading
them at apply time through a data source.

The first half (installing and configuring Vault) is useful no matter what you later integrate it
with — Terraform, Ansible, CI/CD, or Kubernetes.

---

## 📌 Topics Covered

- Why secrets management matters
- Installing HashiCorp Vault on Ubuntu from the official package repository
- Dev server vs. production server
- Vault concepts: Secrets Engines, Access (AppRole), Policies — and their AWS IAM analogies
- Enabling a KV secrets engine and creating a secret
- Creating a policy and an AppRole, and retrieving a Role ID and Secret ID
- Terraform's `provider "vault"` block and AppRole login
- `resource` (create) vs. `data` (read)
- Injecting a Vault-sourced secret into an AWS resource
- Common errors and their fixes
- Operational notes about the dev server

---

## 📁 What's in This Folder

```
7-vault-secrets/
├── README.md                    ← you are here
├── main.tf                      ← AWS + Vault providers, data source, EC2 instance tagged with the secret
├── variables.tf
├── terraform.tfvars.example
└── vault-setup/
    ├── install-vault.sh         ← installs Vault on Ubuntu
    ├── configure-vault.sh       ← enables KV, creates secret, policy, AppRole; prints Role ID + Secret ID
    └── terraform-policy.hcl     ← the Vault policy attached to the AppRole
```

---

## 1. Why Secrets Management?

Hardcoding a password or token in `.tf` files means it lands in Git, in CI logs, and in anyone's
screen share. A secrets manager stores values encrypted, controls **who** can read them, and lets
tools like Terraform fetch them only when needed.

> HashiCorp Vault is one of the most popular choices, and integrates with Ansible, Terraform, CI/CD
> pipelines, and Kubernetes. This module deliberately sticks to one simple path — a basic **KV
> (key-value)** secret — to avoid overwhelm. The same overall process applies to other secret engine types.

## 2. Vault Concepts, Simplified

| Vault concept | What it is | AWS analogy |
|---|---|---|
| **Secrets Engine** | A "type" of secret you can store. KV = simple key-value pairs; others cover Kubernetes, cloud credentials, and more. Mounted at a path you choose. | — |
| **Access (Auth Method)** | How users or tools authenticate to Vault. Options include JWT, OIDC, TLS, username/password. **AppRole** is the most common for tool integrations. | An IAM **role** |
| **Policy** | Defines *what* an authenticated identity may access. | An IAM **policy** attached to a role |
| **Role ID + Secret ID** | The AppRole credentials a tool uses to log in. | Access Key ID + Secret Access Key |

A fresh Vault install has **nothing** enabled — no engines, no users, no policies. Everything has to be
created explicitly.

**Why Vault is popular:** values are encrypted as soon as they're written. Even at the storage level,
only the encrypted form exists; the decrypted value is only available through Vault itself.

## 3. Dev Server vs. Production Server

| Mode | Use for | Notes |
|---|---|---|
| **Dev server** | Learning, demos, proof of concept | Easy to start, in-memory, **no persistence** |
| **Production server** | Real organizational use | Needs TLS/certificates and persistent storage, built out properly |

Analogy: Minikube for learning Kubernetes vs. running a real cluster on EKS.

> ⚠️ **A dev server loses everything on restart** — secret, engine, policy, and AppRole must all be
> recreated from scratch. `vault-setup/configure-vault.sh` exists precisely so you can redo that in
> one command.

## 4. Setting Up Vault (Step by Step)

### Step 1 — Launch an Ubuntu EC2 instance for Vault
Use an **Ubuntu** AMI (the commands below are Ubuntu-specific; CentOS and others differ). SSH in:

```bash
ssh -i <key> ubuntu@<vault-instance-public-ip>
```

### Step 2 — Install Vault
Vault isn't in Ubuntu's default repositories, so you add HashiCorp's official package repo first.
General principle: when a package isn't in your distro's default repos, either download it manually or
add the vendor's repo. This is what [`vault-setup/install-vault.sh`](./vault-setup/install-vault.sh) does:

1. Update the package index and install `gpg`
2. Download HashiCorp's signing key (used to verify the repository)
3. Add the HashiCorp repository to your apt sources
4. `sudo apt update` (always, after adding a new repo)
5. `sudo apt install vault`
6. Verify by running `vault` — it prints usage help

### Step 3 — Start the dev server
Run it in **one terminal**, in the foreground, so you can see logs while you work:

```bash
vault server -dev -dev-listen-address="0.0.0.0:8200"
```

> `0.0.0.0` makes the dev server reachable from outside the instance. Without it, Vault only listens
> on localhost and the UI/Terraform couldn't reach it. On startup it prints an **Unseal Key** and a
> **Root Token** — copy the root token.

Open a **second SSH session** for all further commands, and point the CLI at the server:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='<root-token-from-first-terminal>'
```

### Step 4 — Open port 8200 in the security group
By default an EC2 security group only allows SSH. Add an inbound rule:
**Custom TCP, port 8200** (restrict the source to your own IP rather than `0.0.0.0/0` wherever possible).
Then visit `http://<vault-instance-public-ip>:8200` for the Vault UI.

### Step 5 — Log in to the UI with the root token
Paste the root token. (In a real org, Vault would integrate with LDAP or an OIDC identity provider
instead of using the root token.)

### Step 6 — Enable a KV secrets engine
UI: *Secrets Engines → Enable new engine → KV*, with path `kv`. Or via CLI:

```bash
vault secrets enable -path=kv kv-v2
```

> The **path** is just the mount point. If you see a conflict (e.g. a `secret/` path already exists in
> dev mode), simply use a different one — `kv` is used throughout this folder.

### Step 7 — Create a secret

```bash
vault kv put kv/test-secret username=abhishek
```

This creates a secret named `test-secret` containing the key `username`. Right now only the root user
can read it — Terraform has no access yet.

### Step 8 — Create a policy, then an AppRole
Just as in AWS you create an IAM policy before attaching it to a role, in Vault you create the **policy
first**. [`terraform-policy.hcl`](./vault-setup/terraform-policy.hcl) grants read access to the `kv`
mount. Then you create the **AppRole** and attach the policy via `token_policies`.

> ⚠️ Creating AppRoles, writing policies, and fetching the Role ID / Secret ID are **CLI-only** — the
> Vault UI doesn't support them. Hence `configure-vault.sh`.

### Step 9 — Retrieve the Role ID and Secret ID
These are Vault's equivalent of AWS access keys. **Treat both as highly sensitive. Never share or
commit them.**

Everything in Steps 6–9 is automated by:

```bash
cd vault-setup
./configure-vault.sh
```

## 5. The Terraform Side

### Providers
Terraform has a `vault` provider alongside `aws`. The AWS provider is still needed because the secret
will ultimately be used on an AWS resource.

```hcl
provider "vault" {
  address          = var.vault_address        # must include http:// — see "Common Errors"
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}
```

| Field | Purpose |
|---|---|
| `address` | Vault URL **including scheme and port**, e.g. `http://<ip>:8200` |
| `skip_child_token` | Recommended by HashiCorp for token-based auth — avoids generating excessive child tokens |
| `auth_login.path` | `auth/approle/login` tells Terraform to authenticate via AppRole |
| `role_id` / `secret_id` | The credentials from Step 9, passed in as **sensitive variables** |

### `resource` vs. `data`
- **`resource`** → *create* something
- **`data`** → *read* something that already exists

That's "the only difference" in syntax between creating and reading in Terraform.

### Reading the secret

```hcl
data "vault_kv_secret_v2" "example" {
  mount = "kv"            # the path chosen when the KV engine was enabled
  name  = "test-secret"   # the secret's name
}
```

### Using it on a resource

```hcl
resource "aws_instance" "example" {
  # ...
  tags = {
    secret = data.vault_kv_secret_v2.example.data["username"]
  }
}
```

> **Indexing matters:** `data.vault_kv_secret_v2.example.data` alone returns the *entire* key-value
> map. To get just one value, index in with the exact key name: `["username"]`.

The same pattern injects any sensitive value into any attribute — an S3 bucket name, a Lambda
function name, and so on.

### Verify authentication *before* adding resources
A successful `terraform init` only proves the provider plugin installed — it does **not** prove Vault
authentication works. Auth is only tested when Terraform actually reads a `data` block. So: add the
provider and data block first, run `terraform apply` (it will show `0 added`), and confirm it succeeds
before adding the EC2 resource.

## 6. Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `parse first segment in URL cannot contain colon` | Vault `address` is missing the `http://` scheme | Use `http://<ip>:8200` |
| `error making API request` / `invalid secret_id` | The Secret ID is expired, already used up, or the dev server was restarted (wiping the AppRole) | Regenerate the Role ID and Secret ID and update your variables; see note below |
| `inconsistent dependency lock file` | Providers changed since the last `init` | Re-run `terraform init` (add `-upgrade` if needed) |
| `the given key does not identify an element in the collection value` | The key in `data["..."]` doesn't match the key stored in Vault | Use the exact key name, e.g. `["username"]` |

**About the intermittent `invalid secret_id` error:** AppRole Secret IDs can carry a **TTL** and a
**use limit**. If the role was created with defaults that expire or limit usage, a Secret ID that
worked a moment ago can suddenly fail. `configure-vault.sh` sets `secret_id_ttl=0` and
`secret_id_num_uses=0` (no expiry, unlimited uses) so the demo is stable — **do not use those settings
in production**; review each parameter against the official Vault documentation.

## 7. Extending the Pattern — S3 Bucket Name From a Secret

You can use the same Vault value as a bucket name. Caveat: **S3 bucket names must be globally unique**
across all of AWS, so a bare value like `abhishek` will almost certainly fail. Combine it with a unique
prefix or suffix, or store a more unique value in Vault. A commented-out example is in `main.tf`.

## 8. ⚠️ Security Notes

- **Secrets read through a data source are written into the Terraform state file** — exactly the
  exposure problem from folder `4/`. Keep state in a secured remote backend, and avoid putting truly
  critical secrets into resource attributes where they're also visible in the AWS console (this demo's
  tag is visible to anyone who can view the instance — it's an illustration, not a pattern for real secrets).
- Pass `role_id` and `secret_id` via `terraform.tfvars` (git-ignored) or `TF_VAR_*` environment
  variables — never hardcode them in `.tf` files.
- Restrict port 8200 to your own IP, and use a production Vault with TLS for anything real.

---

## ▶️ How to Run This

```bash
# --- On the Vault EC2 instance (Ubuntu) ---
git clone <your-repo-url> && cd <repo>/7/vault-setup
./install-vault.sh

# Terminal 1 — keep running in the foreground:
vault server -dev -dev-listen-address="0.0.0.0:8200"

# Terminal 2:
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='<root-token-from-terminal-1>'
./configure-vault.sh          # prints a Role ID and Secret ID — copy them

# --- On your Terraform machine ---
cd 7
cp terraform.tfvars.example terraform.tfvars   # fill in vault_address, role_id, secret_id, ami_value, subnet_id

terraform init
terraform plan
terraform apply

# verify: EC2 console -> your instance -> Tags -> secret = abhishek

terraform destroy
```

> Remember: restarting the Vault dev server wipes everything. Re-run `configure-vault.sh` and update
> `terraform.tfvars` with the new Role ID / Secret ID.

---

## ✅ Key Takeaways

- Secrets management is a core DevOps skill across Terraform, Ansible, CI/CD, and Kubernetes.
- Vault installs from HashiCorp's official repo; the **dev server** is for learning (no persistence), the **production server** needs TLS and storage.
- Secrets Engine = type of secret; Secret = encrypted key-value data; AppRole = how tools authenticate; Policy = what they may access — mirroring IAM roles and policies.
- AppRole, policy, and Role ID / Secret ID steps are CLI-only.
- In Terraform: `provider "vault"` authenticates; `resource` creates; `data` reads.
- A successful `terraform init` does **not** verify Vault auth — only applying a `data` block does.
- Index into the data map with the exact key (`["username"]`) to get a single value.
- Values read from Vault end up in Terraform state — protect state with a remote backend.
