# 🧠 **CKAD: Preferred NodeAffinity for Balanced Scheduling**

📚 **Official Kubernetes Documentation**: [Assigning Pods to Nodes - Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity)

### 🏢 **Context**
You are working 🧑‍💻 as a **Platform Engineer** managing GPU workloads.  
Your team noticed that a critical Deployment is scheduling most of its **10 replicas** on a single node, causing resource imbalance.
Both cluster nodes have GPU labels, but the scheduler needs guidance to **prefer** distributing Pods across both nodes.

### ❓ **Question**
A Deployment manifest is provided at:
```
/app/app.yaml
```
The Deployment currently schedules most of its Pods on a single node.
Your cluster has two nodes:
* `controlplane`
* `node01`

Both nodes contain GPU labels:
```
gpu.vendor=nvidia
gpu.count=1
```
The Deployment runs **10 replicas**.

---
### **Your Tasks**
1. Edit **only** the file `/app/app.yaml`.
2. Add **NodeAffinity using `preferredDuringSchedulingIgnoredDuringExecution`** so that the scheduler *prefers* to place Pods on nodes that have **both** labels:
   * `gpu.vendor = nvidia`
   * `gpu.count = 1`
3. Use a **weight of 50** for the preference.
4. Ensure the Deployment remains eligible to run its Pods across both nodes based on preferred affinity.
5. Do **not** change the number of replicas.
6. Apply the updated Deployment manifest.

---
### Try it yourself first!
<details><summary>✅ Solution (expand to view)</summary>

> `weight: 50` in preferred NodeAffinity only influences scoring and cannot ensure equal pod distribution—use topologySpreadConstraints with `maxSkew: 1` for guaranteed even spreading.

Edit the file `/app/app.yaml` and add the `affinity` section under `spec.template.spec`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: app-flask
  name: app-flask
  namespace: app
spec:
  replicas: 10
  selector:
    matchLabels:
      app: app-flask
  strategy: {}
  template:
    metadata:
      labels:
        app: app-flask
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            preference:
              matchExpressions:
              - key: gpu.vendor
                operator: In
                values:
                - nvidia
              - key: gpu.count
                operator: In
                values:
                - "1"
      containers:
      - image: public.ecr.aws/docker/library/httpd:alpine
        name: httpd
        ports:
        - containerPort: 80
```
Then apply it:
```bash
kubectl apply -f /app/app.yaml
```
Wait a moment and verify the distribution:
```bash
kubectl get pods -n app -o wide
```

Check pod distribution across nodes:
```bash
kubectl get pods -n app -o wide | grep -i node01 | wc -l
kubectl get pods -n app -o wide | grep -i controlplane | wc -l
```
</details>
