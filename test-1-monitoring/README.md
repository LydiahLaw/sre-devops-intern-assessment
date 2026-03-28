# Test 1 — Monitoring Stack

## Environment

- Local Kubernetes cluster using [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker)
- Docker Desktop with WSL2 on Windows
- Kubernetes version: v1.29.2
- Simulates an AKS-equivalent environment for assessment purposes



## Part A — Tool Selection & Justification

### Logging Stack: Promtail + Loki + Grafana

| Tool | Role |
|---|---|
| Loki | Log aggregation and storage |
| Promtail/Loki Canary | Log collection from pods |
| Grafana | Log visualisation and querying |

**Why Loki over EFK (Elasticsearch + Fluentd + Kibana):**

Loki indexes only metadata labels rather than full log content, making it significantly lighter on resources — important in a cost-conscious AKS environment. It also uses the same Grafana instance as Prometheus, meaning the team maintains one UI for both logs and metrics rather than two separate systems (Grafana + Kibana). For a small-to-medium cluster, Loki's operational overhead is considerably lower than Elasticsearch.

In a production AKS setup, I would use the standalone Loki Helm chart with Azure Blob Storage as the backend rather than filesystem storage, and deploy Promtail as a DaemonSet for log collection. The `loki-stack` chart used here is deprecated but functional for a lab environment.

### Metrics Stack: Prometheus + Grafana

**Why Prometheus over Azure Monitor:**

Prometheus is the de facto standard for Kubernetes metrics. The `kube-prometheus-stack` Helm chart ships with pre-built alerting rules, kube-state-metrics, and node-exporter out of the box, covering cluster health immediately without custom configuration. Azure Monitor is a strong choice for Azure-native teams already paying for the integration, but Prometheus gives more flexibility, a richer ecosystem, and is portable across cloud providers.



## Part B — Setup

### Prerequisites
- Docker Desktop with WSL2
- kind
- kubectl
- Helm 3

### Installation Steps
```bash
# Create kind cluster
kind create cluster --name monitoring-lab

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy Prometheus + Grafana + Alertmanager
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=24h

# Deploy Loki
helm install loki grafana/loki \
  --namespace monitoring \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1 \
  --set deploymentMode=SingleBinary

# Access Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Login: admin / admin123
```

### Connecting Loki to Grafana

1. Connections → Data sources → Add data source → Loki
2. URL: `http://loki-gateway.monitoring.svc.cluster.local`
3. Save & test

### Demo workloads deployed
```bash
kubectl create namespace demo
kubectl create deployment nginx-demo --image=nginx --replicas=3 -n demo
kubectl create deployment failing-app --image=busybox --replicas=1 -n demo -- sh -c "exit 1"
```

`failing-app` intentionally crashes to generate CrashLoopBackOff events for alert testing.



## Part C — Dashboards

### Dashboard 1 — Cluster Health Overview
Shows CPU usage by namespace, memory usage by namespace, total running pod count, and failed pod count. Failed pods panel turns red when count exceeds zero.

### Dashboard 2 — Application Logs
Shows all pod logs queryable via a Pod dropdown variable. Includes an error log count over time panel filtering for `error`, `failed`, and `exception` log lines.

### Dashboard 3 — On-Call: Pod Restart Tracker
Built for on-call engineers. Shows pod restart counts, current CrashLoopBackOff pod count, container restart rate over time, and pod status distribution as a pie chart.

**Why this dashboard:** An on-call engineer's first question during an incident is what is crashing and how often. A spike in restart rate often precedes a full CrashLoopBackOff by several minutes — catching it early gives the engineer a head start before the situation escalates.


## Alerts

### Alert 1 — Pod CrashLoopBackOff Detected
- **Query:** `count(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}) > 0`
- **Pending period:** 5 minutes
- **Severity:** critical

### Alert 2 — Node CPU High
- **Query:** `(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) by (instance)) * 100 > 80`
- **Pending period:** 3 minutes
- **Severity:** warning

### Alert 3 — High Pod Restart Rate
- **Query:** `sum(rate(kube_pod_container_status_restarts_total[5m])) by (pod) > 0.1`
- **Pending period:** 2 minutes
- **Severity:** warning
- **Why:** A sudden increase in restart rate is an early warning signal that precedes CrashLoopBackOff. Alerting at this stage gives the on-call engineer time to investigate before the pod becomes fully unavailable.



## What I Would Improve in Production

- Replace filesystem storage with Azure Blob Storage for Loki persistence
- Deploy Promtail as a DaemonSet using the standalone chart for structured log collection
- Add Alertmanager routing to PagerDuty or Slack for real notification delivery
- Use Azure Monitor as a complementary layer for AKS control plane metrics not exposed to Prometheus
- Enable Loki query caching with Memcached for performance at scale
- Add network policy restrictions between monitoring components


## Screenshots

| File | Description |
|---|---|
| `screenshots/loki-datasource-connected.png` | Loki data source connected successfully |
| `screenshots/dashboard-cluster-health.png` | Cluster Health Overview dashboard |
| `screenshots/dashboard-app-logs.png` | Application Logs dashboard with pod logs |
| `screenshots/dashboard-oncall.png` | On-Call Pod Restart Tracker dashboard |
| `screenshots/alert-firing.png` | CrashLoopBackOff alert in Firing state |

## Known Limitations

- The new Loki Helm chart exposes only `pod`, `service_name`, and `stream` labels — the `namespace` label is not available without additional Promtail configuration. Dashboard 2 filters by pod only. In production this would be resolved by deploying Promtail as a standalone DaemonSet with explicit namespace relabeling rules.
- The error log count panel shows no data because the demo workloads do not emit lines containing "error" or "failed". The query and panel are correctly configured and would show data with real application logs.
