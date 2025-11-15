# 🧠 **CKA: TopologySpreadConstraints**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)

### 🏢 **Context**

You are working 🧑‍💻 on a **Japan Tourism Platform** that needs high availability across multiple deployment domains (zones).

A Deployment manifest is already stored at:
```bash
/japan-travel-application/japan-tourism.yaml
```

The Deployment has **`7` replicas** that need to be distributed evenly across nodes with different topology domains.

### ❓ **Question**

Edit the Deployment to add a **`topologySpreadConstraints`** section that satisfies the following requirements:

* **Minimum required number of domains** (zones) for balancing: **`2`** 
* **Allowed difference between domains**: **`1`** 
* Use the topology key: `traveljp.io/deployment-domain`
* Ensure the constraint balances Pods across the available nodes only when at least two domains exist
* The `labelSelector` must match the Pod labels: 
  - `app.kubernetes.io/component: frontend`
  - `app.kubernetes.io/version: v1.0.0`
* Use `whenUnsatisfiable: DoNotSchedule` to enforce the constraint
* Do **not modify** replicas or any existing labels

After editing, **apply the Deployment** and verify the Pod distribution.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

First, check the existing file:
```bash
cat /japan-travel-application/japan-tourism.yaml
```

Edit the Deployment:
```bash
vi /japan-travel-application/japan-tourism.yaml
```

Add the `topologySpreadConstraints` section under `spec.template.spec`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/part-of: travel-japan-platform
    team.owner: travel-platform
    workload.type: stateless
  name: travel-jp-recommender
  namespace: japan-tourism-platform
spec:
  replicas: 7
  selector:
    matchLabels:
      app.kubernetes.io/component: frontend
      app.kubernetes.io/version: v1.0.0
  strategy: {}
  template:
    metadata:
      labels:
        app.kubernetes.io/component: frontend
        app.kubernetes.io/version: v1.0.0
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        minDomains: 2
        topologyKey: traveljp.io/deployment-domain
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/component: frontend
            app.kubernetes.io/version: v1.0.0
      containers:
      - image: public.ecr.aws/nginx/nginx:mainline-trixie
        name: backend
        ports:
        - containerPort: 80
        resources: {}
status: {}
```

Apply the Deployment:
```bash
kubectl apply -f /japan-travel-application/japan-tourism.yaml
```

Wait for Pods to be ready:
```bash
kubectl rollout status deployment/travel-jp-recommender -n japan-tourism-platform
```

Verify Pod distribution:
```bash
kubectl get pods -n japan-tourism-platform -o wide
```

Check the distribution count:
```bash
echo "Pods on controlplane (tokyo-a-server):"
kubectl get pods -n japan-tourism-platform -o wide | grep controlplane | wc -l

echo "Pods on node01 (tokyo-b-server):"
kubectl get pods -n japan-tourism-platform -o wide | grep node01 | wc -l
```

Expected result: One node should have 4 Pods, the other should have 3 Pods (difference of 1).

</details>
