# 2. Providers, Variables, TFVars, Conditional Expressions & Built-in Functions

Building on the first EC2 deployment, this module makes Terraform projects **reusable and
environment-aware**: understanding providers in depth, replacing hardcoded values with variables,
supplying values through `terraform.tfvars`, and adapting behaviour per environment with conditionals.

---

## 📁 What's in This Folder

```
2-variables-tfvars/
├── README.md                  ← you are here
├── provider.tf                ← provider configuration
├── input.tf                   ← input variable declarations
├── main.tf                    ← resources (EC2 + security group with conditional)
├── output.tf                  ← output values (public IP, etc.)
├── terraform.tfvars.example   ← copy to terraform.tfvars and fill in your values
└── examples/
    ├── multi-region.tf        ← reference: two regions via provider alias
    └── multi-cloud.tf         ← reference: AWS + Azure in one project
```

> The `examples/` files are **reference only** — Terraform only reads `.tf` files in the folder you
> run it from, so they won't be applied when you run commands in `2/`. Copy one into a scratch folder to try it.

---

## 1. What Is a Provider?

In the first project, the very first thing written was `provider "aws" { region = "us-east-1" }`.

**Thought experiment:** skip the provider block, write only a `resource "aws_instance"`, and run
`terraform apply`. Terraform would have no idea *where* to create the resource or *how to
authenticate* to that cloud.

> **Definition:** A provider is a plugin that tells Terraform where (which cloud/platform) to create
> infrastructure and how to authenticate to it. It is the medium between Terraform and the target platform.

The provider block can optionally include the access key and secret key directly. In the first module
this wasn't needed because the AWS CLI was already configured and Terraform reused those credentials.
(Hardcoding keys in `.tf` files is discouraged — never commit them.)

## 2. Types of Providers

| Type | Who maintains it | Examples |
|---|---|---|
| **Official** | HashiCorp itself — most trustworthy | AWS, Azure, GCP, Kubernetes |
| **Partner** | The platform company writes and maintains it | Alibaba Cloud, Oracle |
| **Community** | Open-source contributors, no official backing | Various |

**Guidance for Community providers:** if it's the only option for a niche platform, check for recent,
active contributions first. If it's unmaintained, don't rely on it. Official and Partner providers
don't carry this concern.

## 3. Multi-Region Setup (`alias`)

To work across two regions of the same cloud, define one provider block per region and give the extra
ones an `alias`. Resources choose which one to use via `provider = aws.<alias>`.

```hcl
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "us_west_2"
}

resource "aws_instance" "example" {
  provider      = aws.us_east_1
  ami           = "<ami-id>"
  instance_type = "t2.micro"
}
```

The alias is just a label — it doesn't have to match the region name. See
[`examples/multi-region.tf`](./examples/multi-region.tf).

## 4. Multi-Cloud (Hybrid Cloud) Setup

For AWS + Azure in one project, each cloud uses its own provider name — no alias needed.

| Cloud | Provider name | Typical auth | Fields if not using CLI auth |
|---|---|---|---|
| AWS | `aws` | IAM-based | Access Key ID, Secret Access Key |
| Azure | `azurerm` | Service Principal | Subscription ID, Client ID, Client Secret, Tenant ID |

Resource names differ too: a VM is `aws_instance` on AWS and `azurerm_virtual_machine` (or the newer
`azurerm_linux_virtual_machine`) on Azure. You can't guess these — always check the official provider
docs. See [`examples/multi-cloud.tf`](./examples/multi-cloud.tf).

> ⭐ **Golden rule:** if you can't create a resource manually in the cloud console, don't try to
> automate it with Terraform yet. Terraform automates existing cloud knowledge — it doesn't replace it.

## 5. Variables — Why They Matter

Hardcoding the AMI and instance type means duplicating the whole project for every team that needs
something slightly different. Variables **parameterize** the project so one codebase serves many uses.

| Variable type | Purpose |
|---|---|
| **Input variable** | Passes values *into* the project (AMI, instance type, etc.) |
| **Output variable** | Prints values *back to you* after `apply` (e.g., the public IP) |

### Input Variables

```hcl
variable "instance_type" {
  description = "The EC2 instance type to use"
  type        = string
  default     = "t2.micro"
}
```

Reference with `var.<name>`:

```hcl
instance_type = var.instance_type
```

| Field | Required? | Purpose |
|---|---|---|
| `description` | Optional | Readability — good habit anyway |
| `type` | Effectively yes | `string`, `bool`, `number`, `list(...)`, `map(...)`, etc. |
| `default` | Optional | Fallback used when no other value is supplied |

If there's no `default`, Terraform needs the value from somewhere else (a `.tfvars` file, `-var`, or an interactive prompt).

### Output Variables

```hcl
output "public_ip" {
  value = aws_instance.example.public_ip
}
```

Format: `<resource_type>.<resource_name>.<attribute>`. Outputs matter because a teammate without AWS
console access can still get the IP straight from Terraform's output.

## 6. Standard Project Structure

| File | Contents |
|---|---|
| `provider.tf` | Provider configuration |
| `input.tf` | Input variable declarations |
| `main.tf` | The actual resource blocks |
| `output.tf` | Output declarations |
| `terraform.tfvars` | Actual values for the input variables |

File names are convention, not requirement — but following them makes any project instantly readable.

## 7. `terraform.tfvars` — Fully Parameterizing a Project

A `default` covers one static case. Real usage changes: `t2.micro` today, `t2.medium` tomorrow.
`terraform.tfvars` supplies values separately from the declarations.

```hcl
instance_type = "t2.medium"
key_name      = "<key-pair-name>"
```

- Terraform **automatically** loads a file named exactly `terraform.tfvars` (and `*.auto.tfvars`).
- A custom name like `dev.tfvars` must be passed explicitly:

```bash
terraform apply -var-file=dev.tfvars
```

**Multi-environment reuse:** keep `dev.tfvars`, `staging.tfvars`, `prod.tfvars` with different values
against the same code (e.g., `t2.micro` for dev, `t2.medium` for prod). Only the tfvars change —
`main.tf`, `input.tf`, and `output.tf` stay untouched.

> 🔒 Real `.tfvars` files often hold sensitive values — keep them out of Git (they're in the root
> `.gitignore`). Commit only the `.example` file.

## 8. Conditional Expressions (Terraform's If-Else)

Sometimes one configuration must behave differently per environment — e.g., an S3 bucket publicly
accessible in Dev (for testing a static site) but private in Production.

**Syntax:** `condition ? true_value : false_value`

**Worked example** — allow SSH from a different CIDR depending on environment:

```hcl
cidr_blocks = [var.environment == "production" ? var.production_subnet_cidr : var.dev_subnet_cidr]
```

Read it as: *"if `environment` equals `production`, use the production CIDR; otherwise use the dev CIDR."*

The same pattern works for booleans, e.g. `var.environment == "production" ? false : true` for a
public-access setting. This is implemented in this folder's `main.tf`.

## 9. Built-in Functions

Terraform ships with built-in functions. They're best learned by using them when a real need appears.

| Function | What it does |
|---|---|
| `length(list)` | Returns the number of elements in a list |
| `lookup(map, key, default)` | Returns the value for `key` in a map, or `default` if missing |
| `tomap({...})` | Converts an object to a map |

> Note: older material mentions a `map()` function. It was removed in modern Terraform — use
> `tomap()` or a plain `{ key = "value" }` object instead.

`length` and `lookup` are demonstrated in this folder's `input.tf` / `output.tf`.
Full list: [Terraform function reference](https://developer.hashicorp.com/terraform/language/functions).

---

## ▶️ How to Run This

```bash
cd 2-variables-tfvars
cp terraform.tfvars.example terraform.tfvars   # then edit with your own values
terraform init
terraform plan
terraform apply

# try a different environment without editing files:
terraform plan -var="environment=production"

terraform destroy   # always clean up
```

---

## ✅ Key Takeaways

- A provider is the plugin that tells Terraform *where* to build and *how to authenticate*; providers are Official, Partner, or Community.
- Multi-region = several provider blocks of the same cloud distinguished by `alias`; multi-cloud = different provider names with cloud-specific auth.
- Learn the manual process in the cloud console first — Terraform automates that knowledge.
- Input variables parameterize a project; output variables report values back after `apply`.
- `terraform.tfvars` lets one codebase serve many teams/environments by swapping values only.
- Conditional expressions (`condition ? a : b`) let one configuration adapt per environment.
- Built-in functions are learned as needed — start with `length` and `lookup`.
