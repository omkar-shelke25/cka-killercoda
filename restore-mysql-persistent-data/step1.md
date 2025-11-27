# 🧠 **CKA: Restore MySQL with Persistent Data**

📚 **[Kubernetes PersistentVolumes Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)**

📚 **[Kubernetes Storage Classes Documentation](https://kubernetes.io/docs/concepts/storage/storage-classes/)**

### 🏢 **Context**

You are working 🧑‍💻 in your company's **platform team**.

Your platform team manages several mission-critical workloads in Kubernetes, including the company's **customer-account MySQL database**, which runs in the **`mysql`** namespace.

Earlier today, a junior engineer accidentally **deleted the MySQL Deployment** during routine maintenance. Fortunately, the database data is **not lost** — the underlying **PersistentVolume (PV)** still exists and is set to **Retain**, meaning the stored data remains intact.

Your task is to restore the MySQL Deployment and ensure that it continues to use the existing persistent data so that customer services depending on this database experience **no data loss**.

### ❓ **Task**

1. A **PersistentVolume** containing the MySQL data already exists and must be reused.A directory must be created on node01 where the MySQL data is stored. (This is the only PV available.)

2. Create a **PersistentVolumeClaim (PVC)** named **`mysql-pvc`** in the **`mysql`** namespace with:
   * **AccessMode**: `ReadWriteOnce`
   * **Storage Request**: `250Mi`

3. Update the MySQL Deployment manifest stored at:
   ```
   ~/mysql-deploy.yaml
   ```
   
   Modify the Deployment so that it mounts the PVC you created (`mysql-pvc`) at the MySQL data directory: **`/var/lib/mysql`**

4. Apply the updated Deployment to the cluster.

5. Validate that:
   * The Deployment is running
   * The Pod is bound to the existing PV via the PVC
   * MySQL is stable and ready

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

```bash
# 🔍 Check the existing PersistentVolume
kubectl get pv
```

You should see a PV named `mysql-pv-retain` with status `Available` and `ReclaimPolicy: Retain`.

```bash
# 🔍 Describe the PV to see its details
kubectl describe pv mysql-pv-retain
```

Note the `storageClassName: manual` and `capacity: 500Mi`.

```bash
# 🔍 Verify the existing data in the PV (on the host)
cat /mnt/mysql-data/movie-booking.sql
```

This confirms the data exists and must not be lost.

---

**Step 1: Create the PersistentVolumeClaim**

Create a PVC manifest:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: mysql
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 250Mi
EOF
```

Verify the PVC is bound to the PV:

```bash
kubectl get pvc -n mysql
```

You should see `STATUS: Bound`.

```bash
kubectl get pv
```

The PV should now show `STATUS: Bound` and `CLAIM: mysql/mysql-pvc`.

---

**Step 2: Update the Deployment to use the PVC**

Edit the Deployment manifest:

```bash
vi ~/mysql-deploy.yaml
```

Add the `volumes` and `volumeMounts` sections:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: mysql
  labels:
    app: mysql
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
        tier: database
    spec:
      containers:
        - name: mysql
          image: mysql:5.7
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "rootpassword123"
            - name: MYSQL_DATABASE
              value: "customerdb"
          ports:
            - containerPort: 3306
              name: mysql
          volumeMounts:
            - name: mysql-persistent-storage
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-persistent-storage
          persistentVolumeClaim:
            claimName: mysql
```

---

**Step 3: Apply the Deployment**

```bash
kubectl apply -f ~/mysql-deploy.yaml
```

---

**Step 4: Verify the Deployment**

Wait for the Pod to be ready:

```bash
kubectl get pods -n mysql -w
```

Check the Pod status:

```bash
kubectl get pods -n mysql
```

Verify the volume is mounted:

```bash
kubectl describe pod -n mysql -l app=mysql
```

Look for the `Mounts:` section showing `/var/lib/mysql`.

Check that the PVC is bound:

```bash
kubectl get pvc -n mysql
```

Verify the existing data is accessible from the Pod:

```bash
kubectl exec -n mysql -it $(kubectl get pod -n mysql -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/lib/mysql
```

You should see the files including `IMPORTANT_DATA.txt`.

```bash
kubectl exec -n mysql -it $(kubectl get pod -n mysql -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- cat /var/lib/mysql/IMPORTANT_DATA.txt
```

This confirms the existing data has been preserved!

---

**Step 5: Validate MySQL is healthy**

Check MySQL logs:

```bash
kubectl logs -n mysql -l app=mysql
```

You should see MySQL initialization messages and "ready for connections".

</details>
