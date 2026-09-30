# 3. Terraform Modules

Building on variables and `tfvars`, this module tackles what happens when a Terraform project grows:
**modularizing** it so it can be reused across teams instead of copy-pasted.

---

## 📌 Topics Covered

- The monolith-vs-microservices analogy applied to Terraform
- Why a single, ever-growing `main.tf` becomes unmanageable
- Advantages of modules: modularity, reusability, collaboration, versioning, abstraction, testing
- Converting a regular project into a reusable module
- Consuming a module from a separate `main.tf`
- Scaling modules across an organization (private module repos)
- Public modules via the Terraform Registry vs. private, org-owned modules

---

## 📁 What's in This Folder

```
3/
├── README.md                        ← you are here
├── main.tf                          ← consuming project: provider + module block
├── terraform.tfvars.example         ← copy to terraform.tfvars for the consuming project
└── modules/
    └── ec2_instance/                ← the reusable module itself
        ├── main.tf                  ← resource logic
        ├── variables.tf             ← expected inputs (no defaults, no tfvars here)
        └── outputs.tf               ← expected outputs
```

> A module folder never contains its own `terraform.tfvars` — values are always supplied by
> whoever *consumes* the module. That's what makes it reusable.

---

## 1. Why Modules? — The Monolith vs. Microservices Analogy

Imagine one company with millions of lines of code, all in a single monolithic application:

- **Onboarding/debugging is slow** — a new developer has to read through the whole codebase to find a bug.
- **No clear ownership** — with hundreds of contributors, nobody can say "these lines are mine."
- **Maintenance is hard** — keeping one giant app patched and secure is a nightmare.
- **Testing is risky** — even a tiny fix means testing (and effectively redeploying) everything.

The software industry solved this with **microservices**. Terraform has the exact same problem at
smaller scale, and the exact same fix: **modules**.

## 2. Mapping the Analogy to Terraform

A DevOps engineer supporting one team on AWS might still need VPCs, EC2 instances, load balancers,
EKS clusters, Lambda functions, S3 buckets, and more — all for that one team. Cram all of it into one
`main.tf` and you've built a monolith:

- A bug is hard to trace back to its owner.
- The project grows to thousands of lines.
- A pull request fixing one resource can accidentally break something unrelated that shares state
  (e.g., a shared subnet reference).

**Solution:** break the project into small, independent, reusable **modules** — one per logical unit
of infrastructure (EC2, VPC, S3, etc.).

## 3. Advantages of Modules

| Advantage | Explanation |
|---|---|
| **Modularity** | Breaks a large project into smaller, manageable units |
| **Reusability** | Write EC2 logic once, reuse it for team XYZ *and* team ABC |
| **Simplified Collaboration** | Teams work on different modules without stepping on each other |
| **Versioning & Maintenance** | Each module can be maintained/versioned independently |
| **Abstraction** | Consumers only need to know inputs/outputs, not internal implementation |
| **Testing** | Test a module in isolation instead of the whole project |
| **Documentation** | Each module documented on its own |
| **Scalability** | New teams reuse existing modules instead of duplicating code |
| **Security** | Ownership and access boundaries are clearer per module |

## 4. Building a Module — Step by Step

### Step 1 — Start as a normal project
Write the resource with everything variabilized (no hardcoded values) — exactly like folder `2/`:
provider block, `variables.tf`, `main.tf`, `outputs.tf`, and a `terraform.tfvars` to run it standalone.

### Step 2 — Move it into a module folder
Create a folder (here: `modules/ec2_instance/`) and move in **`main.tf`, `variables.tf`, `outputs.tf`**
— the resource logic, its expected inputs, and its expected outputs.

### Step 3 — Delete the `terraform.tfvars` from the module
A module should never contain its own `.tfvars`. Values come from whoever calls it. This is the
single biggest gotcha for people modularizing for the first time.

### Step 4 — Write a separate `main.tf` that consumes the module
This represents a different project, team, or even a different repository:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "ec2_instance" {
  source = "./modules/ec2_instance"

  ami_value            = var.ami_value
  instance_type_value  = var.instance_type
  subnet_id_value      = var.subnet_id
  key_name_value       = var.key_name
}
```

| Field | Purpose |
|---|---|
| `module "ec2_instance"` | Arbitrary local name for this module instance |
| `source` | Where to fetch the module from — a relative path (same repo) or a full Git/Registry URL (different repo) |
| Remaining lines | Pass values into the module's declared variables |

### Step 5 — Run it

```bash
terraform init      # also fetches/registers the local module
terraform plan       # shows the resources the module will create
terraform apply
```

The `terraform.tfstate` for this project lives at the **consumer's** root — not inside the module folder.

## 5. Result and Benefit

Once modularized, hundreds of teams can create an EC2 instance by writing **only the short
module-calling block** — no need to write `main.tf`, `variables.tf`, `outputs.tf`, or a `tfvars` file
themselves. Maintenance is centralized: fix a bug once in the module, and every consumer benefits.

This scales beyond one resource type too — nothing stops you from having a separate module per
resource (`modules/ec2_instance/`, `modules/vpc/`, `modules/s3_bucket/`, etc.), all called from the
same consuming project.

## 6. Scaling Modules Across an Organization

In a real org, the module folder doesn't have to live next to the consuming project — it commonly
lives in its own dedicated repository (e.g. `terraform-modules`), housing an EC2 module, a VPC module,
an EKS module, and so on. Other teams are simply told: *"the modules already exist — write a short
`main.tf` that calls them and pass in your values,"* usually backed by a bit of documentation.

## 7. Public vs. Private Modules

| | Public (Terraform Registry) | Private (your own repo) |
|---|---|---|
| **Analogy** | Public Docker Hub images | Private container registry images |
| **Trust/Risk** | Anyone can use them, maintainer unknown — use at your own risk | Fully controlled and understood by your org |
| **Real-world usage** | Rare for production infra | Most companies write and host their own |
| **Referencing** | Copy example code straight from the Registry page | Reference via `source` — relative path (same repo) or full URL (different repo) |

The [Terraform Registry](https://registry.terraform.io/browse/modules) is conceptually like Docker Hub —
searching "ec2 instance" surfaces existing, publicly published modules you can drop straight into a
project. Most real organizations still prefer writing and maintaining their own.

---

## ▶️ How to Run This

```bash
cd 3
cp terraform.tfvars.example terraform.tfvars   # fill in your own values
terraform init
terraform plan
terraform apply

terraform destroy   # always clean up
```

To prove reusability yourself: copy `main.tf` + `terraform.tfvars.example` into a new scratch folder,
change the `source` path to `../3/modules/ec2_instance`, and call the same module again with different
values — no changes needed inside `modules/ec2_instance/` itself.

---

## ✅ Key Takeaways

- Modules solve the same problems microservices solve for application code: ownership, maintenance, and testing.
- Advantages: modularity, reusability, collaboration, versioning, abstraction, testing, documentation, scalability, security.
- To modularize: move resource + variable + output logic into a module folder, **delete any `tfvars`** from inside it, then create a separate consuming `main.tf` with a `module` block and a `source` path.
- `source` can be a local relative path (same repo) or a full URL (different repo/Registry).
- Most real organizations write and maintain their own private modules rather than relying on public ones.
