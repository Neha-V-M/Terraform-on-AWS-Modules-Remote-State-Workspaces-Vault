# Terraform-on-AWS-Modules-Remote-State-Workspaces-Vault
A structured, hands-on progression through real-world Terraform: from an EC2 deployment to modularized, multi-environment infrastructure with secrets management.

A hands-on journey through Terraform — from writing very first `main.tf` to
provisioning full VPC + EC2 stacks, managing remote state, running provisioners, handling
multiple environments with workspaces, and integrating secrets management with HashiCorp Vault.

The goal isn't just to read Terraform syntax — it's to
understand *why* each concept exists by tying it back to a real DevOps scenario (a dev team
requesting infrastructure, a growing project that needs modularizing, a team that needs
Dev/Staging/Prod environments, etc.).

---

## 📚 Table of Contents

| - | Topic | Folder |
|-----|-------|--------|
| [1.](#-1--introduction-to-iac-first-ec2-deployment) | Introduction to IaC, Terraform setup, first EC2 deployment | [`1-ec2-basics/`](./1-ec2-basics) |
| [2.](#-2--providers-variables-tfvars--conditional-expressions) | Providers, input/output variables, `terraform.tfvars`, conditionals | [`2-variables-tfvars/`](./2-variables-tfvars) |
| [3.](#-3--terraform-modules) | Terraform modules — theory + full modularization demo | [`3-modules/`](./3-modules) |
| [4.](#-4--state-file-remote-backends--state-locking) | State file deep dive, S3 remote backend, DynamoDB locking | [`4-state-backend/`](./4-state-backend) |
| [5.](#-5--provisioners--zero-touch-app-deployment) | Provisioners — VPC + EC2 + zero-touch app deployment | [`5-provisioners/`](./5-provisioners) |
| [6.](#-6--terraform-workspaces) | Workspaces — managing Dev/Staging/Prod from one project | [`6-workspaces/`](./6-workspaces) |
| [7.](#-7--secrets-management-with-hashicorp-vault) | Secrets management — integrating Terraform with Vault | [`7-vault-secrets/`](./7-vault-secrets) |

---

## 🗂 Repo Structure

```
Terraform-on-AWS-Modules-Remote-State-Workspaces-Vault/
├── README.md                  ← you are here
├── .gitignore
├── 1.-ec2-basics/
│   ├── main.tf
│   └── notes.md
├── 2.-variables-tfvars/
│   ├── provider.tf
│   ├── input.tf
│   ├── output.tf
│   ├── main.tf
│   ├── terraform.tfvars.example
│   └── notes.md
├── 3.-modules/
│   ├── modules_ec2_instance/
│   ├── main.tf
│   └── notes.md
├── 4.-state-backend/
│   ├── main.tf
│   ├── backend.tf
│   └── notes.md
├── 5.-provisioners/
│   ├── main.tf
│   ├── app.py
│   └── notes.md
├── 6.-workspaces/
│   ├── modules/ec2_instance/
│   ├── main.tf
│   └── notes.md
└── 7.-vault-secrets/
    ├── main.tf
    └── notes.md
```

---

## 🧭 Breakdown

### 1 — Introduction to IaC & Your First EC2 Deployment
- What Infrastructure as Code (IaC) is, and why manual/console-based provisioning doesn't scale
- Why Terraform (provider-agnostic, single HCL language) over cloud-native tools like CloudFormation/ARM
- Installing Terraform (macOS/Linux/Windows) or using **GitHub Codespaces** as a zero-install option
- Configuring AWS credentials (`aws configure`)
- Anatomy of `main.tf`: provider block + resource block
- The core lifecycle: `terraform init` → `plan` → `apply` → `destroy`
- Basics of the `terraform.tfstate` file

### 2 — Providers, Variables, TFVars & Conditional Expressions
- Provider types (Official / Partner / Community), multi-region and multi-cloud provider configs
- Input variables vs. output variables
- Standard project structure: `provider.tf`, `input.tf`, `output.tf`, `main.tf`
- Parameterizing a project fully with `terraform.tfvars`
- Conditional expressions (`condition ? true_val : false_val`) for per-environment logic
- Built-in functions (`length`, `map`, etc.)

### 3 — Terraform Modules
- The monolith-vs-microservices analogy applied to Terraform projects
- Advantages of modules: reusability, abstraction, versioning, simplified collaboration, testing
- Full demo: build a project → structure it (`variables.tf`, `outputs.tf`, `tfvars`) → convert it into a
  reusable module → consume the module from a separate `main.tf`
- Public modules via the Terraform Registry vs. private, org-owned modules

### 4 — State File, Remote Backends & State Locking
- Why the state file is "the heart of Terraform" (enables safe updates + safe destroys)
- Drawbacks of local state: sensitive data exposure, version-control sync risk
- Setting up an **S3 remote backend** step by step
- Implementing **state locking with DynamoDB** to prevent concurrent-apply conflicts
- Correct order of operations: create backend resources *before* activating the backend config

### 5 — Provisioners & Zero-Touch App Deployment
- Real scenario: provision a VPC + public subnet + EC2 instance, then auto-deploy a Flask app
- Why `user_data` isn't enough for non-trivial deployments
- `connection` blocks, the `self` keyword, and the `file` + `remote-exec` provisioners
- Creation-time vs. destroy-time provisioners; `local-exec` for logging
- Why `terraform destroy` matters (avoiding surprise AWS bills)

### 6 — Terraform Workspaces
- The problem: swapping `.tfvars` files against one state file *mutates* the same resource instead of
  creating separate environments
- The fix: **Workspaces** — one state file per environment under `terraform.tfstate.d/`
- Key commands: `terraform workspace new|select|show`
- Dynamic per-environment values using `terraform.workspace` + `lookup()` against a map variable
- ⚠️ Safety warning: always verify the active workspace before `apply`/`destroy`

### 7 — Secrets Management with HashiCorp Vault
- Installing and running Vault (dev mode) on an EC2 instance
- Vault concepts: Secrets Engines, Access (AppRole), Policies
- Creating a KV secret, a policy, and an AppRole (CLI-only steps)
- Terraform's `provider "vault"` block, `data` vs `resource` for reading vs. creating
- Reading a secret with `vault_kv_secret_v2` and injecting it into an AWS resource (e.g., an EC2 tag)
- Generalizing the pattern to any sensitive value (S3 bucket names, Lambda names, etc.)

---

## ▶️ How to Run Any Project

```bash
cd folder-name
terraform init
terraform plan
terraform apply
# ...verify in the AWS console...
terraform destroy   # always clean up to avoid unexpected billing
```

## 🔒 A Note on Secrets

No real AWS credentials, AMI IDs, subnet IDs, key pair names, or Vault Role/Secret IDs are committed
to this repo. Placeholder values (e.g., `<ami-id>`, `<subnet-id>`) are used throughout — supply your
own via `terraform.tfvars` or environment variables.

## 🙋 About This Repo

This repo documents my personal walkthrough of the *Terraform * journey, including the
mistakes and live-debugging moments — because that's usually where the real learning happens.
Feel free to fork it, open issues, or suggest improvements.

## 📄 License

MIT — feel free to reuse for your own learning.
