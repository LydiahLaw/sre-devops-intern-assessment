# Scenario 1 — Pods Running But Application is Unreachable

## How I Read This Scenario

The symptom is a **connection timeout**, not a connection refused or an HTTP error.
This distinction matters before running a single command:

- **Connection refused** → something is actively rejecting the connection. Look at the app or service.
- **HTTP 4xx/5xx** → the request is reaching the app. Look at the app itself.
- **Timeout** → the packet is disappearing. Look at the network path.

"No recent code changes" is also a red flag, not a reassurance. In AKS,
infrastructure changes constantly without anyone touching application code
node pool upgrades, Azure Policy enforcement, NSG rule drift, certificate
expiry, Load Balancer health probe changes. I treat this as "no one changed
the app" not "nothing changed."


## 1. First 3 kubectl Commands

Most people start with `kubectl get pods` but we already know pods are Running.
Starting there wastes time. I start where the timeout points: the network path.
```bash
# 1. Check if the service has endpoints — if this is empty, traffic has nowhere to go
kubectl get endpoints <service-name> -n <namespace>
```
This is my first command because an empty endpoints list immediately tells me
the service selector does not match the pod labels. No amount of correct
ingress or NSG configuration fixes that.
```bash
# 2. Check the ingress and what address it has been assigned
kubectl get ingress -n <namespace> -o wide
```
A missing or pending external IP on the ingress means the load balancer was
never provisioned or was provisioned and lost its IP. This is where AKS
and Azure diverge from vanilla Kubernetes.
```bash
# 3. Describe the service to see the actual port mapping and selector
kubectl describe service <service-name> -n <namespace>
```
I want to confirm the targetPort matches what the container is actually
listening on not what the Dockerfile says, not what the developer told me,
but what the process is actually bound to.



## 2. Which Resource to Check First and Why

I do not check them in the order most people suggest (Deployment → Service →
Ingress). I follow the packet.

A request comes in from outside. It hits:
**DNS → Load Balancer → Ingress → Service → Pod**

Since the symptom is a timeout at the external URL, the failure is most
likely between the Load Balancer and the Ingress, or between the Ingress and
the Service. I work from the outside in:

**Ingress first** — does it have an external IP? Is the host rule matching
the URL being called? Is the backend service name and port correct?

**Service second** — does it have endpoints? Is the selector matching pod
labels? Is the port and targetPort correct?

**Deployment last** — pods are Running, so the deployment is not the problem.
I check it only to verify labels match the service selector.



## 3. Testing at Each Layer

Rather than guessing, I isolate each layer:

**Pod level — bypass everything above it:**
```bash
kubectl exec -it <any-pod> -n <namespace> -- curl localhost:<container-port>
```
If this fails, the application process is not listening correctly.
If this succeeds, the pod is fine and the problem is above it.

**Service level — bypass ingress:**
```bash
kubectl port-forward svc/<service-name> 8080:<service-port> -n <namespace>
# Then in another terminal:
curl http://localhost:8080
```
If this works, the service and pod are healthy. The problem is at the
ingress or network layer. If this fails, the service selector or port
mapping is wrong.

**Ingress level — check the controller logs:**
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
```
Ingress controller logs will show whether requests are arriving and what
is happening to them. A timeout at the external URL with no entries in
the ingress logs means requests are not reaching Kubernetes at all
the problem is outside the cluster entirely.


## 4. Two Azure-Specific Things That Could Cause This

These are the two I would check that most Kubernetes troubleshooting guides
do not mention:

**1. NSG rules blocking the Load Balancer health probe**

AKS provisions an Azure Load Balancer that health-probes your nodes before
routing traffic. If an NSG rule applied by Azure Policy, a security team,
or automated compliance tooling blocks the health probe source IP ranges,
the Load Balancer marks all backends as unhealthy and drops all traffic.
The pods are Running. The service has endpoints. Everything in Kubernetes
looks correct. But Azure is silently discarding packets upstream.

To check: Azure Portal → Load Balancer → Health Probes → see probe status.
Also check NSG flow logs in Network Watcher for denied traffic.

**2. AKS node pool upgrade cycling nodes without pod disruption budgets**

AKS performs automatic node upgrades. During an upgrade, nodes are cordoned
and drained. If the application has no PodDisruptionBudget and no more than
one replica, all pods get evicted simultaneously during the drain. New pods
start on the new node, they show Running but they may still be
initialising when the readiness probe fires. The service has endpoints
because Kubernetes adds the pod to endpoints when it is Running, not when
it is actually ready, if the readiness probe is misconfigured.

The result: external timeout because the load balancer is sending traffic
to pods that are not yet serving. No code changed. No one did anything.
AKS maintenance did it automatically.

To check:
```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
kubectl describe nodes | grep -A5 "Conditions:"
```
