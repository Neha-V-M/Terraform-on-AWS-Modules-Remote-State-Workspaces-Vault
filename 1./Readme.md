# 1. Introduction to Infrastructure as Code & Your First EC2 Deployment

This module covers the *why* behind Infrastructure as Code, why Terraform specifically, environment
setup, and writing + running your first real Terraform project to launch an AWS EC2 instance.

---

## 1. Why Infrastructure as Code?

**The manual problem:** creating a single resource (e.g., an S3 bucket) via the AWS Console takes a
couple of minutes. That's fine once — but it doesn't scale when 100 teams need the same thing.

**The programmatic fix:** use the AWS CLI or an SDK (e.g., Boto3) to script resource creation. Faster,
but now you need programming skills, and complex asks (a VPC + HA EC2 + S3 endpoint) require real
scripting effort.

**The IaC solution:** cloud providers introduced *templating* — declare what you want in JSON/YAML and
let the provider's engine handle the rest:

| Cloud Provider | IaC Tool | Format |
|---|---|---|
| AWS | CloudFormation Templates (CFT) | JSON / YAML |
| Microsoft Azure | Azure Resource Manager (ARM) | JSON / YAML |
| OpenStack | Heat Templates | YAML |

> **Definition:** Infrastructure as Code means using code — scripts or declarative templates — to
> automate the creation and management of infrastructure, instead of doing it manually through a UI.

**The catch:** each provider's tool only talks to that provider. ARM only automates Azure. CFT only
automates AWS. An org working across multiple clouds would need to learn a different tool per cloud.

## 2. Why Terraform

Terraform is **provider-agnostic** — one templating language (**HCL** — HashiCorp Configuration
Language) works across AWS, Azure, GCP, and more. You tell Terraform which provider to target, and it
speaks that provider's native API on your behalf.

**How it works internally — "API as Code":** whatever you write in HCL, Terraform converts into API
calls against the target provider (AWS API calls for `provider "aws"`, Azure API calls for
`provider "azurerm"`, etc.), then executes those calls to actually create the infrastructure.

**Licensing note:** Terraform's license changed and it's no longer fully open source — this mainly
affects companies *building tools on top of* Terraform, not end users. Alternatives exist (Crossplane,
Pulumi), but Terraform still holds the largest market share and remains the most commonly
interview-tested tool.

## 3. Environment Setup

### Option A — Local Install
- **macOS / Linux:** grab the install commands from the official Terraform downloads page for your OS/architecture and run them in a terminal.
- **Windows:** download the installer, keep clicking Next — it's usually added to PATH automatically. Use **Git Bash** or **PowerShell**, not CMD.

### Option B — GitHub Codespaces (no local install needed)
Useful if you're on a restricted work laptop or a low-resource machine.

| Attribute | Detail |
|---|---|
| Free usage | 60 hours/month |
| Specs | 2 CPUs, 4 GB RAM |
| Roughly | ~2 hrs/day across 30 days |

**Setup steps:**
1. Fork this repo → open it → **Code → Codespaces → +** to create a Codespace.
2. Check `terraform -version` and `aws --version` (neither installed by default).
3. Command Palette → *Add Dev Container Configuration Files* → *Modify your active configuration* → search **Terraform** (pick the verified option) → OK.
4. Repeat for **AWS CLI**.
5. Command Palette → **Rebuild Container** (takes ~5–10 min).
6. Re-verify both versions — both should now show as installed.

> Don't delete the `devcontainer.json` file — the Codespace can be closed and reopened later with tools still installed, as long as you reuse the same Codespace/branch.

### AWS Credentials
- Best practice: use an **IAM user**, not root (root is used here only for a simple first demo).
- AWS Console → Security Credentials → Access keys → **Create access key**.
- In the terminal: `aws configure` → enter Access Key ID, Secret Access Key, default region (e.g. `us-east-1`), default output format (e.g. `json`).
- Verify with: `aws s3 ls`.

⚠️ **Never share your Access Key / Secret Access Key with anyone**, including teammates.

> Note: this only authenticates the AWS CLI/machine. Terraform itself still needs its own `provider` block to talk to AWS.

## 4. Anatomy of `main.tf`

Terraform config files use the `.tf` extension. `main.tf` is the conventional name for the primary file
(any name technically works).

### Provider Block
Tells Terraform *which cloud* and *where* (region) to operate.

```hcl
provider "aws" {
  region = "us-east-1"
}
```

### Resource Block
Declares *what* to create. One resource block per resource.

```hcl
resource "aws_instance" "example" {
  ami           = "<ami-id>"
  instance_type = "t2.micro"
  subnet_id     = "<subnet-id>"
  key_name      = "<key-pair-name>"
}
```

> Don't memorize resource syntax — copy it from the [Terraform Registry](https://registry.terraform.io/)
> documentation. Even experienced engineers do this. You do, however, need to understand the
> underlying cloud concepts (AMI, subnet, VPC) — Terraform automates steps you'd otherwise do manually.

## 5. The Core Terraform Workflow

| Command | Purpose |
|---|---|
| `terraform init` | Initializes the working directory, reads `.tf` files, downloads required provider plugins. Run from the folder containing your `.tf` files. |
| `terraform plan` | Dry run — shows exactly what will be created/changed/destroyed, without making changes. Always run before `apply`. |
| `terraform apply` | Actually provisions the infrastructure. Prompts for `yes`/`no` confirmation. |
| `terraform destroy` | Reads the state file and tears down everything Terraform previously created. |

**Sequence used in this module:** `init` → `plan` → `apply` → (later) `destroy`.

> Common early mistake: running `terraform init` from the wrong directory gives
> *"Terraform initialized in an empty directory."* Fix: `cd` into the folder with your `.tf` files first.

## 6. Live Debugging Walkthrough

Errors are a normal part of the process — here's the sequence of issues you're likely to hit on a first
real run, and how to fix each:

| Error | Cause | Fix |
|---|---|---|
| `terraform plan` fails right after configuring credentials | Access keys were rotated/deleted | Re-run `aws configure` with a fresh key pair |
| `apply` fails: AMI does not exist | Invalid/placeholder AMI ID in the resource block | Copy a valid AMI ID from EC2 Console → Launch Instance |
| `apply` fails: "no subnets found for default VPC... please specify a subnet" | No `subnet_id` specified | Copy a subnet ID from VPC Console → Subnets, add `subnet_id = "<subnet-id>"` |
| Instance created but you can't log into it | No SSH key pair specified | Copy an existing key pair name from EC2 Console → Key Pairs, add `key_name = "<key-pair-name>"` |
| Re-run `apply` | All required fields now valid | `Apply complete!` — verify the instance in the EC2 console |

**Helper tooling:** install the **HashiCorp Terraform** and **HCL** VS Code extensions for
auto-completion (e.g., typing `sub` suggests `subnet_id`).

## 7. The State File — Basics

After running Terraform, a `terraform.tfstate` file appears in your working directory. It records
everything Terraform has created, so future runs know what already exists vs. what's new.

- `cat terraform.tfstate` (or `terraform show`) to inspect it.
- Run `terraform destroy` + confirm `yes` when done, to avoid ongoing billing.

> Deferred to a later module: securing sensitive data in the state file, remote vs. local state,
> and running Terraform in CI/CD.

## 8. Complete Lifecycle Summary

| Phase | What It Does |
|---|---|
| 1. `terraform init` | Initializes config, fetches provider plugins, sets up auth |
| 2. `terraform plan` | Dry run — shows the diff, no real changes |
| 3. `terraform apply` | Provisions the real infrastructure (after confirmation) |
| 4. `terraform destroy` | Tears down what Terraform created, based on the state file |

---

## ✅ Key Takeaways

- IaC replaces manual, UI-driven infrastructure creation with declarative, repeatable code.
- Terraform's advantage over CFT/ARM/Heat is being a single, provider-agnostic tool (HCL → API calls).
- A minimal project needs just a `provider` block and one or more `resource` blocks.
- The core lifecycle is `init` → `plan` → `apply` → `destroy` — always `plan` before `apply`.
- The state file is how Terraform tracks what already exists — don't delete it carelessly.

---

## ▶️ How to Run This

```bash
cd 1.
terraform init
terraform plan
terraform apply     # confirm with "yes"

# ...verify the instance in the AWS EC2 console...

terraform destroy   # confirm with "yes" — always clean up
```

> Fill in your own `<ami-id>`, `<subnet-id>`, and `<key-pair-name>` in `main.tf` before running.
