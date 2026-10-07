# 6. Terraform Workspaces — Managing Multiple Environments From One Project

Building on the modules pattern, this module solves a new problem: the same team now needs Dev,
Staging, and Production versions of the same infrastructure — without duplicating the project three
times, and without environments stomping on each other's state.

---

## 📌 Topics Covered

- Why simply swapping `.tfvars` files against one project does **not** create separate environments
- How that failure mode shows up in practice (a `change`, not an `add`)
- Terraform Workspaces as the fix — one state file per environment
- Key commands: `workspace new`, `select`, `show`
- Avoiding repeated manual edits to a shared `.tfvars` file
- The elegant approach: `terraform.workspace` + `lookup()` against a map variable
- ⚠️ The safety risk workspaces introduce, and how to guard against it

---

## 📁 What's in This Folder

```
6-workspaces/
├── README.md                  ← you are here
├── main.tf                    ← consuming project: provider + module block
├── variables.tf                ← instance_type defined as a map, keyed by environment
├── terraform.tfvars.example
└── modules/
    └── ec2_instance/            ← same reusable module pattern as folder 3/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 1. The New Problem: Multiple Environments

Team "XYZ" already has a working module-based project (see folder `3/`) tested in Dev with
`t2.micro`. Now they also need Staging (`t2.medium`) and Production (`t2.xlarge`) — and some orgs
have 5 or even 10 environments. Recreating the whole project per environment clearly doesn't scale.

## 2. First (Flawed) Attempt — Multiple `.tfvars` Files

The intuitive fix: keep one `main.tf`, but maintain `dev.tfvars`, `stage.tfvars`, `prod.tfvars`, and
pass the right one at apply time:

```bash
terraform apply -var-file=dev.tfvars     # creates a Dev instance
terraform apply -var-file=stage.tfvars    # intention: create a SEPARATE Staging instance
```

**This does not work the way you'd want.** There's only **one state file** for the whole project by
default, and it has no concept of "environment" — it only tracks resources by their Terraform resource
address (e.g. `module.ec2_instance.aws_instance.example`), not by which `.tfvars` file configured them.

**What actually happens:** the second command doesn't add a new instance — Terraform sees the *same*
resource address now described with a different `instance_type`, and proposes to **change** (or
replace) the existing Dev instance to match Staging's values. You lose Dev, you don't gain a separate
Staging environment.

> You can reproduce this yourself: apply once with `terraform.tfvars`, then run
> `terraform plan -var-file=terraform.tfvars` after editing only the `instance_type` — Terraform will
> show `~ update in-place`, not `+ create`.

## 3. The Solution: Terraform Workspaces

> **Definition:** Workspaces maintain a **separate state file per environment**, all within the same
> project — no separate folders, no separate copies of `main.tf`.

Terraform stores these under `terraform.tfstate.d/<workspace-name>/`, one subfolder per workspace. You
can create as many as you need (`dev`, `stage`, `prod`, or more).

**Why this fixes it:** while you're in the `dev` workspace, only the Dev state file is read/updated.
Switch to `stage`, and only the Staging state file is touched. Applying in one workspace never
conflicts with, overwrites, or modifies resources tracked by another workspace's state.

## 4. Key Workspace Commands

| Command | Purpose |
|---|---|
| `terraform workspace new <name>` | Creates a new workspace and its own state subfolder |
| `terraform workspace select <name>` | Switches the current session to that workspace |
| `terraform workspace show` | Shows which workspace is currently active |
| `terraform workspace list` | Lists all workspaces |

```bash
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod

terraform workspace select dev
terraform workspace show        # → dev
```

> There is always a default workspace named `default`, present even if you never create any others.

## 5. Best Practice: Don't Keep Manually Editing One Shared `.tfvars`

Switching workspaces and then manually editing the same `terraform.tfvars` each time (changing
`instance_type` by hand before every apply) works, but it's manual and error-prone — defeating the
point of automation. Two better options:

1. **One `.tfvars` per environment**, passed explicitly: `terraform apply -var-file=prod.tfvars`
2. **Dynamic resolution** using the built-in `terraform.workspace` variable + `lookup()` — the more
   elegant option, and what this folder implements.

## 6. The Elegant Approach — `terraform.workspace` + `lookup()`

Terraform automatically exposes `terraform.workspace`, which always resolves to the name of the
currently active workspace (`"dev"`, `"stage"`, `"prod"`, …).

**Step 1 — define `instance_type` as a map, not a string**, with one entry per environment:

```hcl
variable "instance_type" {
  description = "Instance type per environment"
  type        = map(string)
  default = {
    dev   = "t2.micro"
    stage = "t2.medium"
    prod  = "t2.xlarge"
  }
}
```

**Step 2 — resolve the right value with `lookup()`:**

```hcl
instance_type_value = lookup(var.instance_type, terraform.workspace, "t2.micro")
```

`lookup(map, key, default)` takes: (1) the map to search, (2) the key to look up — here, whatever
`terraform.workspace` currently resolves to, and (3) a fallback if that key isn't found.

**Result:** switch to the `stage` workspace and this expression automatically resolves to
`"t2.medium"` — **no tfvars editing required** when switching environments. This folder's `main.tf`
implements exactly this pattern.

## 7. ⚠️ Critical Safety Warning

> Be **very** careful with workspaces: there is no built-in guard against running a destructive
> command against the wrong one. If you intend to destroy Staging but are actually in the `prod`
> workspace and type `yes`, **Production is gone** — with no undo.

Terraform does display the active workspace in its confirmation prompt, but it's easy to not read it
carefully, especially when running commands quickly or from a script.

**Guardrails worth adopting:**
- Always run `terraform workspace show` before `apply` or `destroy`.
- Read the confirmation prompt fully before typing `yes`.
- In CI/CD, make the workspace an explicit, visible pipeline parameter — never implicit.

---

## ▶️ How to Run This

```bash
cd 6-workspaces
cp terraform.tfvars.example terraform.tfvars   # fill in ami_value and subnet_id (instance_type is per-env, see variables.tf)

terraform init

# --- create the workspaces ---
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod

# --- Dev ---
terraform workspace select dev
terraform workspace show        # confirm: dev
terraform plan                   # resolves to t2.micro automatically
terraform apply

# --- Staging ---
terraform workspace select stage
terraform plan                   # resolves to t2.medium — no tfvars edit needed
terraform apply                  # adds a SEPARATE instance, Dev is untouched

# --- Production ---
terraform workspace select prod
terraform plan                   # resolves to t2.xlarge
terraform apply

# --- cleanup, one environment at a time ---
terraform workspace select stage
terraform workspace show        # double-check before destroying!
terraform destroy

terraform workspace select dev
terraform destroy

terraform workspace select prod
terraform destroy
```

---

## ✅ Key Takeaways

- Workspaces solve managing Dev/Staging/Prod from **one** project — no duplicated `main.tf` or folders.
- Simply swapping `.tfvars` against one shared state file does not create separate environments — it mutates the one resource that single state file tracks.
- Each workspace gets its **own independent state file**, under `terraform.tfstate.d/<workspace>/`.
- Core commands: `terraform workspace new|select|show`.
- Prefer `terraform.workspace` + `lookup()` against a map variable over manually re-editing a shared `.tfvars` file for each environment.
- **Always confirm the active workspace** before `apply` or `destroy` — the wrong one can mean destroying production by mistake.
