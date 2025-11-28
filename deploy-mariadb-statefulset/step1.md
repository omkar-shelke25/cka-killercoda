## 🧠 Deploy MariaDB StatefulSet with Persistent Storage

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

A financial application requires a replicated MariaDB database cluster with persistent storage and stable network identities. 

You need to deploy a StatefulSet that ensures each database replica maintains its own persistent data and has a predictable DNS name.

### 🛠️ Your tasks:

1. Create a namespace named **`database`**

2. Create a **Headless Service** named **`mariadb`** in the `database` namespace that:
   * Selects Pods with label `app: mariadb`
   * Exposes port `3306` (MariaDB default port)
   * Uses `clusterIP: None` to make it headless

3. Deploy a **StatefulSet** named **`mariadb`** in the `database` namespace with:
   * 🔢 **3 replicas**
   * 🐳 Image: `mariadb:10.6`
   * 🏷️ Pod labels: `app: mariadb`
   * 🔐 Environment variable: `MARIADB_ROOT_PASSWORD=rootpass`
   * 📁 Data directory: `/var/lib/mysql` (mounted from persistent storage)
   * 💾 **Persistent Volume Claim (volumeClaimTemplate)**:
     - Storage class: `local-path` (pre-configured in the cluster)
     - Access mode: `ReadWriteOnce`
     - Storage size: `250Mi`
     - Claim name: `mariadb-data`

4. 🔍 Verify:
   * All 3 StatefulSet Pods are running
   * Each Pod has its own PersistentVolumeClaim
   * Pods have stable DNS names (e.g., `mariadb-0.mariadb.database.svc.cluster.local`)

**Note:** The `local-path` StorageClass is already configured in your cluster for dynamic volume provisioning.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Task 1: Create namespace**

```bash
kubectl create namespace database
```

**Task 2: Create Headless Service**

```bash
cat > /tmp/mariadb-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: database
  labels:
    app: mariadb
spec:
  clusterIP: None  # Headless service
  selector:
    app: mariadb
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
    protocol: TCP
EOF

kubectl apply -f /tmp/mariadb-service.yaml
```

**Task 3: Create StatefulSet with PersistentVolumeClaim**

```bash
cat > /tmp/mariadb-statefulset.yaml <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mariadb
  namespace: database
spec:
  serviceName: mariadb
  replicas: 3
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.6
        env:
        - name: MARIADB_ROOT_PASSWORD
          value: "rootpass"
        ports:
        - name: mysql
          containerPort: 3306
          protocol: TCP
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: mariadb-data
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: local-path
      resources:
        requests:
          storage: 250Mi
EOF

kubectl apply -f /tmp/mariadb-statefulset.yaml
```

**Task 4: Verify Deployment**

Check StatefulSet status:
```bash
kubectl get statefulset -n database
```

Check Pods:
```bash
kubectl get pods -n database -l app=mariadb
```

Watch Pods being created:
```bash
kubectl get pods -n database -l app=mariadb -w
```

Check PersistentVolumeClaims:
```bash
kubectl get pvc -n database
```

Check PersistentVolumes:
```bash
kubectl get pv
```

Verify Pod details:
```bash
kubectl describe statefulset mariadb -n database
```

Test DNS resolution (from within cluster):
```bash
# Run a temporary pod to test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -n database -- sh

# Inside the pod, test DNS:
nslookup mariadb-0.mariadb.database.svc.cluster.local
nslookup mariadb-1.mariadb.database.svc.cluster.local
nslookup mariadb-2.mariadb.database.svc.cluster.local
```

Test MariaDB connection:
```bash
# Connect to the first replica
kubectl exec -it mariadb-0 -n database -- mysql -uroot -prootpass -e "SELECT 1;"

# Connect to second replica
kubectl exec -it mariadb-1 -n database -- mysql -uroot -prootpass -e "SELECT 1;"
```

Check logs:
```bash
kubectl logs mariadb-0 -n database
```

</details>
