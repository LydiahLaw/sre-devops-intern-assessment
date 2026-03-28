# Test 2 — Infrastructure Automation

## Environment

- Cloud Provider: AWS (eu-central-1)
- Terraform v1.14.8
- Ansible core 2.20.3
- Deployed from WSL2 on Windows

> Azure is listed as preferred but AWS was used as it is my primary cloud platform with existing credentials and tooling configured. The infrastructure patterns (VPC, subnets, security groups, EC2) map directly to Azure equivalents (VNet, subnets, NSGs, VMs).

---

## Part A — Tool Choice & Justification

### Tools Used: Terraform + Ansible

**Terraform** handles all infrastructure provisioning — VPC, subnets, internet gateway, route tables, security groups, EC2 instances, and key pairs. Terraform is the right tool here because infrastructure resources have a lifecycle (create, update, destroy) that benefits from state management. Declaring resources in HCL makes the intent readable and reviewable.

**Ansible** handles VM configuration after provisioning — installing nginx, setting the hostname, and creating a deploy user with SSH access. Ansible is purpose-built for configuration management — it connects over SSH without requiring an agent on the target machine, and playbooks are idempotent, meaning running the same playbook twice produces the same result without breaking anything.

**Why not Terraform alone:** Terraform can run remote-exec provisioners but they are fragile, hard to maintain, and HashiCorp discourages using them for configuration management. Ansible is the right tool for that layer.

**Why not Ansible alone:** Ansible can create AWS resources but lacks state management. If you run it twice it tries to create the same resources again. Terraform tracks state and knows what already exists.

### Secrets Handling

- `my_ip` is marked `sensitive = true` in variables.tf — Terraform will not print it in logs
- `terraform.tfvars` is added to `.gitignore` — never committed to the repository
- SSH private key stays local — only the public key is uploaded to AWS
- AWS credentials are configured via `aws configure` — never hardcoded in any file

---

## Part B — What Was Provisioned

### Architecture
```
Internet
    │
    ▼
[VPC: 10.0.0.0/16]  vpc-06a444ea0c67508be
    │
    ├── Public Subnet (10.0.1.0/24)
    │       │
    │       └── VM1 — sre-assessment-vm1-gateway
    │               Public IP:  3.71.177.78
    │               Private IP: 10.0.1.196
    │               nginx installed and running
    │
    └── Private Subnet (10.0.2.0/24)
            │
            └── VM2 — sre-assessment-vm2-appserver
                    Private IP: 10.0.2.136
                    No public IP — internal only
```

### Resources Created (11 total)

| Resource | Name |
|---|---|
| VPC | sre-assessment-vpc |
| Public Subnet | sre-assessment-public-subnet |
| Private Subnet | sre-assessment-private-subnet |
| Internet Gateway | sre-assessment-igw |
| Route Table | sre-assessment-public-rt |
| Route Table Association | public subnet → IGW |
| Security Group (VM1) | sre-assessment-vm1-sg |
| Security Group (VM2) | sre-assessment-vm2-sg |
| Key Pair | sre-assessment-key |
| EC2 Instance (VM1) | sre-assessment-vm1-gateway |
| EC2 Instance (VM2) | sre-assessment-vm2-appserver |

### Firewall Rules

**VM1 Security Group:**
- Port 22 (SSH) → your IP only
- Port 80 (HTTP) → 0.0.0.0/0
- Port 443 (HTTPS) → 0.0.0.0/0
- All outbound → allowed

**VM2 Security Group:**
- All traffic from VM1 security group → allowed
- All traffic from private subnet CIDR → allowed
- All other inbound → denied

---

## Remote State

State is stored remotely in S3 with DynamoDB locking:

| Resource | Name |
|---|---|
| S3 Bucket | sre-assessment-tfstate-835960997504 |
| DynamoDB Table | sre-assessment-tfstate-locks |
| Encryption | AES256 server-side encryption |
| Versioning | Enabled |

This means multiple engineers can work on the same infrastructure without corrupting state, and every state change is versioned and recoverable.

---

## Module Structure
```
terraform/
├── main.tf          # Root module — calls all child modules
├── variables.tf     # Input variable definitions
├── outputs.tf       # Output values
├── terraform.tfvars # Actual values (gitignored)
└── modules/
    ├── vpc/         # VPC, subnets, IGW, route tables
    ├── security/    # Security groups for VM1 and VM2
    └── compute/     # EC2 instances, key pair, AMI lookup
```

---

## How to Run

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Ansible >= 2.9
- SSH key pair generated (`ssh-keygen -t ed25519 -f ~/.ssh/sre-assessment`)

### Steps
```bash
# 1. Clone the repo
git clone https://github.com/LydiahLaw/sre-devops-intern-assessment.git
cd sre-devops-intern-assessment/test-2-automation

# 2. Create terraform.tfvars (gitignored — create manually)
cat > terraform/terraform.tfvars << 'TFVARS'
project_name        = "sre-assessment"
aws_region          = "eu-central-1"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
availability_zone   = "eu-central-1a"
instance_type       = "t2.micro"
key_name            = "sre-assessment-key"
public_key_path     = "~/.ssh/sre-assessment.pub"
my_ip               = "YOUR_PUBLIC_IP"
TFVARS

# 3. Deploy infrastructure
cd terraform
terraform init
terraform plan -out=tfplan 2>&1 | tee plan-output.txt
terraform apply "tfplan"

# 4. Update ansible/inventory.ini with VM1 public IP from terraform output
# 5. Run Ansible
cd ..
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

---

## Ansible Configuration Applied to VM1

| Task | Result |
|---|---|
| Set hostname | sre-gateway |
| Install nginx | Installed and enabled |
| Start nginx | active (running) |
| Create deploy user | deployuser created |
| Add SSH key | sre-assessment.pub added |
```
PLAY RECAP
vm1: ok=9  changed=6  unreachable=0  failed=0  skipped=0
```

---

## What I Would Add in Production

- **NAT Gateway:** So VM2 can reach the internet for package updates without a public IP
- **Azure equivalent:** Replace aws provider with azurerm — VNet, NSGs, and Azure VMs follow the same modular pattern
- **Ansible Vault:** Encrypt sensitive variables like passwords in playbooks
- **ALB + ACM:** Put an Application Load Balancer in front of VM1 with a proper TLS certificate
- **Auto Scaling:** Add an ASG behind the ALB for VM1 to handle traffic spikes
- **Monitoring:** Deploy the Prometheus + Loki stack from Test 1 onto this infrastructure
