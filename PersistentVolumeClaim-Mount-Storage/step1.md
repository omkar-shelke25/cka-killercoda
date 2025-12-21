# 🧠 **CKA: PersistentVolumeClaim - Mount Storage to Nginx Deployment**

📚 **[Kubernetes PersistentVolumes Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)**

### 🏢 **Context**

You are working 🧑‍💻 as a **Platform Engineer** at a tech company building a cyberpunk-themed web portal.  
The infrastructure team has already created a **PersistentVolume** backed by local SSD storage on **node01**.

Your task is to claim this storage and mount it to the Nginx deployment so that the application can persist its web content.

### ❓ **Question**

The following resources are already configured:

1. **PersistentVolume**: A PV named `nginx-pv` with 700Mi capacity exists (manifest at `/src/nginx/nginx-pv.yaml`)
2. **Deployment manifest**: Located at `/src/nginx/nginx-deployment.yaml` (needs volume configuration)
3. **Service**: A NodePort service is already deployed at port 30339
4. *Before creating the PVC and mounting it, ensure that the PV is available, properly configured, and verify where the data is stored.*

**Your tasks:**

1. **Create a PersistentVolumeClaim** that:
   - Is named `nginx-pv-claim`
   - Is created in the `nginx-cyperpunk` namespace
   - Binds to the existing `nginx-pv` PersistentVolume
   - Requests 350Mi of storage
   - Uses `storageClassName: local-path`
   - Save the manifest as `/src/nginx/nginx-pvc.yaml` and apply it

2. **Update the Deployment** at `/src/nginx/nginx-deployment.yaml` to:
   - Add a volume using the PVC `nginx-pv-claim`
   - Mount this volume to the container at path `/usr/share/nginx/html`
   - The volume should be named `nginx-pv`

3. **Deploy** the updated deployment to the `nginx-cyperpunk` namespace.Verify that the NodePort (30339) is accessible.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

### Step 1: Check the existing PersistentVolume

```bash
# View the PV
kubectl get pv nginx-pv
kubectl describe pv nginx-pv
```

You should see it has 700Mi capacity, uses local-path storage class, and has node affinity to node01.

### Step 2: Create the PersistentVolumeClaim

```bash
# Create the PVC manifest
cat <<EOF > /src/nginx/nginx-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pv-claim
  namespace: nginx-cyperpunk
spec:
  storageClassName: local-path
  volumeName: nginx-pv
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 350Mi
EOF

# Apply the PVC
kubectl apply -f /src/nginx/nginx-pvc.yaml
```

### Step 3: Verify the PVC is bound

```bash
kubectl get pvc -n nginx-cyperpunk
```

The STATUS should show `Bound`.

### Step 4: Update the Deployment to mount the PVC

```bash
vi /src/nginx/nginx-deployment.yaml
```

Add the `volumes` and `volumeMounts` sections:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-scifi-portal
  namespace: nginx-cyperpunk
  labels:
    app: nginx-scifi
    tier: frontend
    project: scifi-portal
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-scifi
  template:
    metadata:
      labels:
        app: nginx-scifi
        tier: frontend
        project: scifi-portal
    spec:
      volumes:
        - name: nginx-pv
          persistentVolumeClaim:
            claimName: nginx-pv-claim
      containers:
        - name: nginx-scifi
          image: nginx
          ports:
            - containerPort: 80
              name: nginx-server
          volumeMounts:
            - mountPath: "/usr/share/nginx/html"
              name: nginx-pv
```

### Step 5: Deploy the application

```bash
kubectl apply -f /src/nginx/nginx-deployment.yaml
```

### Step 6: Verify the deployment

```bash
# Check pods are running
kubectl get pods -n nginx-cyperpunk -o wide

# Check that all pods are on node01 (due to PV's node affinity)
kubectl get pods -n nginx-cyperpunk -o wide | grep node01

# Verify the volume mount
kubectl describe pod -n nginx-cyperpunk -l app=nginx-scifi | grep -A 5 "Mounts:"

# Check the service
kubectl get svc -n nginx-cyperpunk
```

### Step 7: Test the application (optional)

```bash
# Create a test file in the mounted volume
POD_NAME=$(kubectl get pods -n nginx-cyperpunk -l app=nginx-scifi -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n nginx-cyperpunk $POD_NAME -- sh -c 'echo "Welcome to Cyberpunk Nginx Portal!" > /usr/share/nginx/html/index.html'

# Test via service
curl http://localhost:30339
```

</details>
