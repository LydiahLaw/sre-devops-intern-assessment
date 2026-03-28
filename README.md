# SRE / DevOps Intern — Take-Home Technical Assessment

**Candidate:** Lydiah Nganga
**GitHub:** [LydiahLaw](https://github.com/LydiahLaw)

---

## Repository Structure

| Folder | Contents |
|---|---|
| `test-1-monitoring/` | Monitoring stack — Prometheus, Loki, Grafana on Kubernetes |
| `test-2-automation/` | Infrastructure automation — Terraform + Ansible on AWS |
| `test-3-troubleshooting/` | Troubleshooting scenario answers |

---

## Test 1 — Monitoring Stack

Deployed a full observability stack on a local Kubernetes cluster (kind) simulating AKS:

- **Metrics:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- **Logging:** Loki in SingleBinary mode with Grafana as the single UI for both
- **Dashboards:** Cluster Health, Application Logs, On-Call Pod Restart Tracker
- **Alerts:** CrashLoopBackOff detection, Node CPU threshold, High restart rate

See [test-1-monitoring/README.md](test-1-monitoring/README.md) for full details.

---

## Test 2 — Infrastructure Automation

Provisioned a two-tier network architecture on AWS using Terraform modules + Ansible:

- **VPC** with public and private subnets
- **VM1** (gateway) — public IP, nginx installed via Ansible, SSH restricted to my IP
- **VM2** (app server) — no public IP, reachable only from VM1
- **Remote state** — S3 backend with DynamoDB locking and AES256 encryption

See [test-2-automation/README.md](test-2-automation/README.md) for full details.

---

## Test 3 — Troubleshooting Scenarios

- [Scenario 1](test-3-troubleshooting/scenario-1.md) — Pods Running but application unreachable

---

## Tools Used

| Tool | Version |
|---|---|
| Terraform | v1.14.8 |
| Ansible | core 2.20.3 |
| Helm | v3.20.1 |
| kubectl | v1.29.2 |
| kind | v0.22.0 |
| AWS CLI | v2 |
