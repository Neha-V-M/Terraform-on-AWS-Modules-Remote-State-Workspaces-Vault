# 5. Provisioners — VPC, EC2 & Zero-Touch App Deployment

A realistic DevOps task: a dev team hands you `app.py` and wants it deployed and reachable by URL every
time they change it. This module builds the full networking stack from scratch (VPC → public subnet →
EC2) and uses Terraform **provisioners** to copy and run the app automatically — no manual SSH required.

---

## 📌 Topics Covered

- The real-world scenario: VPC + public subnet + EC2 + exposed app, on demand
- Why `user_data` isn't enough for anything beyond a trivial script
- Building a VPC and making a subnet public (route table + Internet Gateway)
- Security groups: `ingress` vs `egress`
- The `connection` block and the `self` keyword
- The `file` provisioner (copy files to the instance)
- The `remote-exec` provisioner (run commands on the instance)
- Creation-time vs. destroy-time provisioners; `local-exec` for logging
- Why `terraform destroy` matters (avoiding surprise AWS bills)

---

## 📁 What's in This Folder

```
5-provisioners/
├── README.md                  ← you are here
├── main.tf                    ← VPC, subnet, IGW, route table, security group, key pair, EC2 + provisioners
├── variables.tf
├── terraform.tfvars.example
└── app.py                     ← the Flask app that gets deployed onto the instance
```

---

## 1. The Scenario

A development team ("XYZ") has a Flask app (`app.py`). Every time they change it, they want it
spun up on fresh infrastructure so they can verify the change — without touching AWS themselves.

**Required infrastructure, per request:**

| # | Step |
|---|---|
| 1 | Create a VPC |
| 2 | Create a **public** subnet inside it (subnet + route table + Internet Gateway + association) |
| 3 | Create an EC2 instance and deploy `app.py` onto it |
| 4 | Expose the app on port 80 and hand back a URL (e.g. `3.4.6.7:80`) |

Doing this manually takes roughly an hour per developer, per change. Automating it with Terraform turns
that into a few minutes — and removes the developer's need to ever touch the AWS console.

## 2. Why Not Just Use `user_data`?

Terraform's `user_data` field runs a script at instance launch — fine for a couple of lines, but not
suited to deploying a real project (imagine 100 files). For anything beyond a trivial bootstrap script,
Terraform offers a dedicated mechanism: **provisioners**.

## 3. Building the Stack

### 3.1 Key Pair
Generate a local key pair, then register the public half with AWS:

```bash
ssh-keygen -t rsa -f ./terraform-key -N ""
```

```hcl
resource "aws_key_pair" "example" {
  key_name   = "terraform-provisioners-key"
  public_key = file("./terraform-key.pub")
}
```

### 3.2 VPC
```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr   # e.g. 10.0.0.0/16
}
```

### 3.3 Subnet
```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = var.subnet_cidr   # e.g. 10.0.1.0/24
  availability_zone        = var.availability_zone
  map_public_ip_on_launch  = true
}
```

### 3.4 Making the Subnet Public
A subnet isn't public by default. It takes four pieces working together:

1. **Internet Gateway** — the VPC's door to the internet
2. **Route table** — routes `0.0.0.0/0` traffic to that gateway
3. **Route table association** — attaches the route table to the subnet

```hcl
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

### 3.5 Security Group
`ingress` = inbound, `egress` = outbound.

```hcl
resource "aws_security_group" "web" {
  name   = "terraform-provisioners-sg"
  vpc_id = aws_vpc.main.id

  ingress {        # app traffic
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {        # SSH, in case something needs manual troubleshooting
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {          # so the instance can reach the internet (apt, pip, etc.)
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 3.6 EC2 Instance
```hcl
resource "aws_instance" "app" {
  ami                    = var.ami_value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
}
```

At this point — VPC, subnet, routing, security group, and instance all exist, and the instance has a
public IP. But the app itself isn't deployed yet.

## 4. Connecting Terraform to the Instance

A `connection` block, placed inside the EC2 resource, tells Terraform *how* to reach it:

```hcl
connection {
  type        = "ssh"
  user        = "ubuntu"                       # matches the Ubuntu AMI used
  private_key = file("./terraform-key")         # the local private key half
  host        = self.public_ip
}
```

> **`self` keyword:** inside a resource block, `self.public_ip` refers to *this same resource's* own
> attribute. Referenced from outside the block, you'd instead write
> `aws_instance.app.public_ip`.

## 5. Deploying the App — `file` + `remote-exec`

Two provisioners, used together, go inside the same `aws_instance` block:

| Provisioner | What it does here |
|---|---|
| `file` | Copies the local `app.py` onto the instance |
| `remote-exec` | Runs shell commands on the instance: install Python/pip, install Flask, run the app |

```hcl
provisioner "file" {
  source      = "app.py"
  destination = "/home/ubuntu/app.py"
}

provisioner "remote-exec" {
  inline = [
    "sudo apt-get update -y",
    "sudo apt-get install -y python3-pip",
    "pip3 install flask",
    "cd /home/ubuntu && nohup python3 app.py > flask.log 2>&1 &"
  ]
}
```

Both provisioners rely on the `connection` block above to know how to reach the instance.

> ⚠️ **Known gotcha (same one hit in the original walkthrough):** running the Flask app as the very
> last `remote-exec` command can sometimes appear to succeed in Terraform's output, but the process
> doesn't actually stay running (the SSH session for `remote-exec` can end before a plain background
> process is fully detached). The `nohup ... &` pattern above is the fix — it fully detaches the
> process from the SSH session. If you still don't see it running, SSH in manually and start it with
> `sudo python3 app.py` to confirm the app itself works, then debug the detachment separately.

## 6. Running It

```bash
terraform plan    # expect 8 resources: VPC, key pair, subnet, route table, IGW,
                    # route table association, EC2 instance, security group
terraform apply
```

**Verifying the deployment:**
```bash
ssh -i terraform-key ubuntu@<public_ip>
ls                              # confirm app.py is present
sudo ps -ef | grep python       # confirm the Flask process is running
curl http://<public_ip>          # or open it in a browser
```

## 7. Why `terraform destroy` Matters

Two concrete reasons to always clean up after a demo/test:

1. **Manual cleanup is error-prone** — with many projects (yours or others'), remembering every
   resource to delete by hand is a losing game.
2. **Unexpected billing** — forgotten NAT Gateways, Elastic IPs, or load balancers can rack up real
   charges, sometimes well beyond what you'd expect from "just a demo."

> Rule of thumb: once you're done verifying a project, run `terraform destroy`.

## 8. Theory — What Is a Provisioner?

> **Definition:** a provisioner lets you copy files or run commands at the time infrastructure is
> created (and optionally, at the time it's destroyed).

By default, a provisioner runs at **creation time**. It can also be configured to run at
**destroy time**, by explicitly adding `when = destroy` to the provisioner block.

### Why Provisioners Exist at All
Terraform is extremely good at provisioning infrastructure, but it doesn't natively know how to
configure or deploy software onto that infrastructure. Without provisioners, you'd need a separate
tool — Ansible, or raw shell scripts connecting out to potentially thousands of instances — just to
bridge that gap. Provisioners let Terraform do this natively.

### Types of Provisioners

| Type | Purpose | Used here? |
|---|---|---|
| `file` | Copy files from local machine to the remote resource | ✅ — copies `app.py` |
| `remote-exec` | Run shell commands directly on the remote resource | ✅ — installs deps, runs the app |
| `local-exec` | Run a command **locally**, not on the remote resource — useful for logging/progress output when console output would be too long to scroll through | Not used in this demo; useful for things like `echo "Task $i of $n complete" >> progress.log` on larger projects |

> As always: don't memorize provisioner syntax. Search the official Terraform docs for `remote-exec`
> or `file` — the documentation ships a ready-made example (an `aws_instance` named `"web"`, complete
> with a sample `connection` and provisioner block) you can adapt directly.

## 9. The Bigger Picture — Zero-Touch Automation

With this project, the developer's ~1-hour manual process becomes: trigger the project (or, once
CI/CD is wired in, just push code) and get back a URL. No manual AWS login, no manual SSH. This
end-to-end flow — provisioning infrastructure **and** deploying the app with zero manual steps — is
what's meant by **zero-touch automation**, and it's a clear example of where DevOps earns its name.

> **Not covered here (future extension):** wiring this into CI/CD — e.g. the dev team pushes `app.py`
> to GitHub, and Jenkins/GitHub Actions automatically pulls the change and re-runs this project.

---

## ▶️ How to Run This

```bash
cd 5-provisioners
ssh-keygen -t rsa -f ./terraform-key -N ""     # generates terraform-key / terraform-key.pub
cp terraform.tfvars.example terraform.tfvars    # fill in your own AMI/region values

terraform init
terraform plan      # expect 8 resources to add
terraform apply

# verify: curl http://<output public_ip> — should return "Hello Terraform"

terraform destroy   # always clean up — this stack includes networking resources that can bill
```

---

## ✅ Key Takeaways

- A common real DevOps task: given an app file, provision VPC + public subnet + EC2 and deploy it automatically.
- Terraform alone creates infrastructure — it doesn't deploy software onto it. **Provisioners** fill that gap.
- A `connection` block (protocol, user, private key, host) tells Terraform how to reach a resource; use `self.<attr>` from within that same resource's own block.
- Three provisioner types: `file` (copy), `remote-exec` (run commands remotely), `local-exec` (run/log locally).
- Always run `terraform destroy` after testing — both for cleanliness and to avoid surprise AWS bills.
- This end-to-end flow (infra + deployment, zero manual steps) is "zero-touch automation."
