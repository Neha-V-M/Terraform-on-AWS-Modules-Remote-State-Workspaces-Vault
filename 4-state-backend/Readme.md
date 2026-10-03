# 4. State File, Remote Backends (S3) & State Locking (DynamoDB)

The state file is "the heart of Terraform." This module covers what it actually does, why keeping it
local or in Git is risky, and how to move it to a secure, team-safe **S3 remote backend** with
**DynamoDB-based locking**.

---

## 📌 Topics Covered

- What the state file is and why Terraform needs it
- How the state file enables safe updates and safe `destroy`
- Drawbacks of local state: sensitive data exposure, version-control sync risk
- Remote backends as the fix, using S3 as the example
- Other backend options (Terraform Cloud, Azure Storage)
- State locking and why concurrent applies are dangerous without it
- Implementing locking with a DynamoDB table
- The correct order of operations (a common real mistake)

---

## 📁 What's in This Folder

```
4-state-backend/
├── README.md                  ← you are here
├── main.tf                    ← EC2 instance + the S3 bucket & DynamoDB table used as the backend
├── backend.tf                 ← S3 backend config — commented out until the bucket/table exist
├── variables.tf
└── terraform.tfvars.example
```

---

## 1. What Is the Terraform State File?

> **Core definition:** the state file is the "heart of Terraform." It records everything Terraform has
> already created, so future runs know what already exists vs. what's new.

When you run `terraform apply`, Terraform both creates the infrastructure **and** records that
infrastructure's details (IDs, AMI, instance type, etc.) into `terraform.tfstate`.

### Advantage 1 — Enables Safe Updates
**Without a state file:** if you add a tag to an existing resource block and re-apply, Terraform has
no memory of having already created that resource — it would just create a *second* one.
**With a state file:** Terraform compares the new config against what it already recorded, recognizes
the resource already exists, and simply updates it (adds the tag) instead of duplicating it.

### Advantage 2 — Enables Safe `terraform destroy`
`terraform destroy` can only tell you exactly what it's about to tear down — and ask for confirmation
— because it reads the state file to know what it previously created.

## 2. Drawbacks of Local State

These are called *drawbacks*, not fundamental flaws — because remote backends fix them.

### Drawback 1 — Sensitive Information Exposure
Terraform stores **everything** about a resource in the state file by default, with no filtering — if
any part of a resource involves a password, token, or secret, it ends up in plaintext in the state
file. Fine on a solo laptop; risky the moment a team shares access to the project or the machine.

### Drawback 2 — Version Control (Git) Risks
If the state file is committed to Git:
- **Repository compromise** — anyone with repo access can read it, even sensitive contents.
- **Sync drift** — if someone changes the Terraform code but forgets to also re-apply and push the
  updated state file, the next person's `plan` will show unexpected, confusing diffs. One forgotten
  step breaks the whole team's view of reality.

## 3. The Fix: Remote Backends

**Definition:** instead of storing the state file locally (or in Git), it's stored in an external,
shared, access-controlled location — e.g. an **AWS S3 bucket**.

| Original Drawback | How a Remote Backend (S3) Fixes It |
|---|---|
| Sensitive data exposed to anyone with repo/machine access | The S3 bucket is private, governed by IAM policy — far more secure than a shared repo or laptop |
| Forgetting to push an updated state file breaks sync | `terraform apply` updates the state **directly in S3** — engineers only push code, never a state file |

When `terraform init` runs against a backend-configured project, Terraform automatically fetches the
state from S3 instead of a local file — the comparison becomes *(S3 state) vs (your code)* instead of
*(local file) vs (your code)*.

**Other backend options:** Terraform Cloud's own backend, or Azure Storage for Azure-based projects —
S3 is just the AWS example used here.

## 4. Backend Configuration — `backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket = "<your-unique-bucket-name>"
    key    = "terraform/terraform.tfstate"
    region = "us-east-1"
  }
}
```

| Field | Purpose |
|---|---|
| `bucket` | Name of the S3 bucket that stores the state file (must be globally unique) |
| `key` | Path/prefix inside the bucket where the state file is stored |
| `region` | AWS region the bucket lives in |

## 5. ⚠️ Correct Order of Operations (Common Mistake)

You cannot activate a backend that points at a bucket (and DynamoDB table) that don't exist yet —
`terraform init` will fail. The correct sequence is:

1. **Comment out `backend.tf`.** Create the S3 bucket and DynamoDB table as *regular resources* in
   `main.tf`, using local state (same as every previous folder).
2. Run `init` → `plan` → `apply` with the backend still commented out. This creates the bucket + table.
3. **Only then**, uncomment `backend.tf`, fill in the real bucket name, and run `terraform init` again.
   Terraform will detect the backend change and prompt to migrate your existing local state into S3.
4. From this point on, every `apply` updates the state directly in S3.

> Doing this in the wrong order produces the classic error: *"backend configuration changed"* or a
> failure to find the bucket/table. If you see that, double-check `backend.tf` is still commented out
> and the bucket/table genuinely exist first.

The `backend.tf` in this folder ships **commented out** for exactly this reason — follow the steps in
[How to Run This](#️-how-to-run-this) below in order.

## 6. State Locking — Why It's Needed

Imagine a 5-person DevOps team. Two engineers run `terraform apply` on the same project within
moments of each other — one setting an S3 bucket policy to public, the other to private. Without
coordination, Terraform (and AWS) receive conflicting instructions nearly simultaneously.

**Locking** fixes this: Terraform locks the state while one execution is in progress. A second,
concurrent execution must wait until the first finishes and releases the lock — guaranteeing changes
apply one at a time, in order.

## 7. Implementing Locking With DynamoDB

Because the state now lives in S3 (not locally), the lock itself needs to live somewhere shared too —
DynamoDB is the standard choice.

| Field | Value |
|---|---|
| Table name | `terraform_lock` |
| Billing mode | Pay-per-request |
| Hash key | `LockID` (string) |

Wire it into `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-unique-bucket-name>"
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_lock"
  }
}
```

> Note: as of Terraform 1.10+, S3-native locking (via the bucket itself, with `use_lockfile = true`)
> is also available and HashiCorp's newer recommended approach — but DynamoDB locking is still widely
> used and is what's demonstrated here, matching the original walkthrough.

**How it works in practice:** while one engineer's `apply` is running, they hold the lock via this
table. Once it completes, the lock releases and the next person's `apply` can proceed. Every `apply`
first checks whether anyone currently holds the lock.

---

## ▶️ How to Run This

This folder requires the two-phase sequence described above — **don't skip straight to step 3.**

```bash
cd 4-state-backend
cp terraform.tfvars.example terraform.tfvars   # fill in your own values

# --- Phase 1: create the backend resources with backend.tf still commented out ---
terraform init
terraform plan      # should show: EC2 instance + S3 bucket + DynamoDB table to add
terraform apply

# --- Phase 2: activate the backend ---
# 1. Open backend.tf and uncomment the `terraform { backend "s3" {...} }` block
# 2. Fill in the real bucket name (the one just created)
terraform init       # Terraform detects the backend change and offers to migrate local state into S3
terraform plan        # state now reads from S3
terraform apply

# --- cleanup ---
terraform destroy    # always clean up to avoid ongoing billing
```

---

## ✅ Key Takeaways

- The state file is the heart of Terraform — it enables safe updates (no accidental duplication) and safe `destroy`.
- Local/Git-stored state has two real risks: sensitive data exposure and version-control sync drift.
- Remote backends (e.g. S3) fix both — storage is access-controlled, and `apply` updates it automatically, no manual state-file pushes.
- Backend config needs `bucket`, `key`, and `region` at minimum.
- **Create the S3 bucket and DynamoDB table first, with the backend commented out** — only activate the backend after both exist.
- State locking (DynamoDB `LockID` table, or newer S3-native locking) prevents two people from applying conflicting changes at the same time.
