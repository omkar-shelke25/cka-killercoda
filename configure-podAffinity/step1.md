# 🧠 **CKA: PodAffinity - Backend Near Frontend**

📚 **[Kubernetes PodAffinity Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity)**

### 🏢 **Context**

You are working 🧑‍💻 in your company's **application infrastructure team**.  
A **nara-frontend** Deployment is already running in the **nara** namespace with 3 replicas on the **controlplane** node.

Your backend team needs to ensure that backend Pods are **always scheduled on the same nodes** as frontend Pods for optimal performance and reduced latency.

### ❓ **Question**

A Deployment named **nara-frontend** is already running in the **nara** namespace with 3 replicas.

A backend Deployment manifest is stored at:
```
/nara.io/nara-backend.yaml
```

Update this file to add *required* PodAffinity so that all nara-backend Pods MUST be scheduled on the same node as nara-frontend Pods, using:

* `requiredDuringSchedulingIgnoredDuringExecution`
* `topologyKey: nara.io/zone`

After updating the manifest, **apply it** to create the backend Deployment.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

```bash
#🔍 View current node labels
kubectl get nodes --show-labels
```


```bash
#🔍 Check which zones the nodes belong to:
kubectl get nodes -L nara.io/zone
```

```bash
#🔍 Check frontend Pod locations
kubectl get pods -n nara -l app=nara-frontend -o wide
```

All frontend Pods should be on **controlplane** (zone-a).

Edit the manifest:
```bash
vi /nara.io/nara-backend.yaml
```

Add the `affinity` section under `spec.template.spec`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nara-backend
  namespace: nara
  labels:
    app: nara-backend
    tier: backend
    project: nara
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nara-backend
  template:
    metadata:
      labels:
        app: nara-backend
        tier: backend
        project: nara
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - nara-frontend
              topologyKey: nara.io/zone
      containers:
        - name: backend
          image: node:alpine
          command: ["sh", "-c", "tail -f /dev/null"]
          ports:
            - containerPort: 3000
```

Apply the manifest:
```bash
kubectl apply -f /nara.io/nara-backend.yaml
```

Verify the Pods are scheduled on the same node:
```bash
kubectl get pods -n nara -o wide
```

All backend Pods should be on **controlplane** (same as frontend).

</details>


