# 🧠 **CKA: PodAntiAffinity - MongoDB High Availability**

📚 **[Kubernetes PodAntiAffinity Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity)**
📚 **[Kubernetes StatefulSets Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)**

### 🏢 **Context**

You are working 🧑‍💻 in your company's **data platform team**.  

Your company operates a production-grade **MongoDB database** on Kubernetes. The StatefulSet is named **`mongodb-users-db`** with **2 replicas** in the **`database-services`** namespace.

Currently, MongoDB pods may be scheduled on the same node, which violates the company's high-availability policy. A single node failure could severely impact or completely take down the MongoDB service.

To comply with production standards, the database team requires **mandatory pod anti-affinity** so that MongoDB replicas **MUST run on different failure domains (zones)**.

### ❓ **Question**

A StatefulSet manifest for MongoDB is stored at:
```
/mongodb/mongodb-stateful.yaml
```

The StatefulSet has already been applied to the cluster but **does NOT have PodAntiAffinity configured**.

Your task:

1. **Delete the existing StatefulSet** to prepare for reconfiguration
2. **Update the manifest** at `/mongodb/mongodb-stateful.yaml` to add *required* PodAntiAffinity so that:
   - Ensure that no two MongoDB pods can run on the same node
   - Use `requiredDuringSchedulingIgnoredDuringExecution`
   - Use `topologyKey: topology.kubernetes.io/zone`

3. **Re-apply the updated manifest** to create the StatefulSet with anti-affinity rules

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

```bash
# 🔍 Check current node labels and zones
kubectl get nodes --show-labels
```

```bash
# 🔍 Check which zones the nodes belong to
kubectl get nodes -L topology.kubernetes.io/zone
```

You should see:
- **controlplane** → `zone-a`
- **node01** → `zone-b`

```bash
# 🔍 Check current MongoDB pod locations
kubectl get pods -n database-services -l app=mongodb-users-db -o wide
```

```bash
# ðŸ—'ï¸ Delete the existing StatefulSet (this will also delete the pods)
kubectl delete statefulset mongodb-users-db -n database-services
```

Wait for all pods to terminate:
```bash
kubectl get pods -n database-services -w
```

Now edit the manifest:
```bash
vi /mongodb/mongodb-stateful.yaml
```

Add the `affinity` section under `spec.template.spec` (right after the `spec:` line in the pod template):

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-users-db
  namespace: database-services
  labels:
    app: mongodb-users-db
    environment: production
    team: data-platform
  annotations:
    owner: "db-team"
spec:
  serviceName: "mongodb"
  replicas: 2
  selector:
    matchLabels:
      app: mongodb-users-db
  template:
    metadata:
      labels:
        app: mongodb-users-db
        environment: production
      annotations:
        description: "MongoDB users database"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - mongodb-users-db
              topologyKey: topology.kubernetes.io/zone
      containers:
        - name: mongodb
          image: mongo:5.0
          ports:
            - containerPort: 27017
              name: mongodb
          volumeMounts:
            - name: mongodb-data
              mountPath: /data/db
  volumeClaimTemplates:
    - metadata:
        name: mongodb-data
        labels:
          app: mongodb-users-db
      spec:
        storageClassName: local-path
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 500Mi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: database-services
  labels:
    app: mongodb-users-db
spec:
  clusterIP: None
  ports:
    - port: 27017
      name: mongodb
  selector:
    app: mongodb-users-db
```

Apply the updated manifest:
```bash
kubectl apply -f /mongodb/mongodb-stateful.yaml
```

Watch the pods being created:
```bash
kubectl get pods -n database-services -l app=mongodb-users-db -w
```

Verify the Pods are scheduled on different nodes:
```bash
kubectl get pods -n database-services -l app=mongodb-users-db -o wide
```

You should see MongoDB pods distributed across **controlplane** and **node01** (one pod per zone).

Check pod status and events:
```bash
kubectl describe pods -n database-services -l app=mongodb-users-db
```

</details>
