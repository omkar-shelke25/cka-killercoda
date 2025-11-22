# 🧠 **CKA: PersistentVolumeClaim with Dynamic Provisioning**

📚 **Official Kubernetes Documentation**: 
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Configure a Pod to Use a PersistentVolumeClaim](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)

### 🔧 **Context**

You are working 🧑‍💻 on preparing a workload that performs local image processing for your company. The `operations` namespace already exists, and a Deployment manifest for the application has been created at `/src/k8s/image-processor.yaml`.

This Deployment is functional but currently does not include any persistent storage. The application needs a cache directory at `/cache` to store temporary processing results that should persist across pod restarts.

The cluster uses the **Rancher Local Path Provisioner** with a StorageClass named `local-path`, which supports dynamic provisioning of local storage on the worker nodes.

### ❓ **Task**

Complete the following tasks to add persistent storage to the image processor application:

1. **Create a PersistentVolumeClaim** named `processor-cache` in the `operations` namespace that:
   - Requests **1Gi** of storage
   - Uses the `local-path` StorageClass
   - Is dynamically provisioned (no manual PV creation needed)

2. **Modify the existing Deployment manifest** at `/src/k8s/image-processor.yaml`:
   - Add a volume that references the PVC `processor-cache`; the volume name should be `cache-storage`.
   - Add a `volumeMount` to mount the PVC at `/cache` inside the container
   - **Do not change any other part of the Deployment**

4. **Apply your changes and verify**:
   - The PVC becomes `Bound`
   - A dynamically provisioned PV is created automatically
   - The running pod mounts the volume at `/cache`
   - You can create and read a file inside `/cache` from the pod

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the StorageClass exists**

```bash
kubectl get storageclass
```

You should see the `local-path` StorageClass available.

```bash
kubectl describe storageclass local-path
```

**Step 2: Create the PersistentVolumeClaim**

Create a file for the PVC:

```bash
cat > /tmp/processor-cache-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: processor-cache
  namespace: operations
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
EOF
```

Apply the PVC:

```bash
kubectl apply -f /tmp/processor-cache-pvc.yaml
```

Verify the PVC is created (it may be Pending until bound to a pod):

```bash
kubectl get pvc -n operations
```

**Step 3: Modify the Deployment manifest**

Edit the Deployment manifest:

```bash
vi /src/k8s/image-processor.yaml
```

Add the volume and volumeMount sections. The modified Deployment should look like this:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-processor
  namespace: operations
  labels:
    app: image-processor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-processor
  template:
    metadata:
      labels:
        app: image-processor
    spec:
      containers:
      - name: processor
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            echo "Image processor starting..."
            echo "Waiting for work..."
            while true; do
              sleep 3600
            done
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        volumeMounts:
        - name: cache-storage
          mountPath: /cache
      volumes:
      - name: cache-storage
        persistentVolumeClaim:
          claimName: processor-cache
```

**Alternative approach using kubectl patch:**

```bash
# Add volume
kubectl patch deployment image-processor -n operations --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes",
    "value": [
      {
        "name": "cache-storage",
        "persistentVolumeClaim": {
          "claimName": "processor-cache"
        }
      }
    ]
  }
]'

# Add volumeMount
kubectl patch deployment image-processor -n operations --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts",
    "value": [
      {
        "name": "cache-storage",
        "mountPath": "/cache"
      }
    ]
  }
]'
```

**Step 4: Apply the Deployment**

```bash
kubectl apply -f /src/k8s/image-processor.yaml
```

**Step 5: Verify the configuration**

Check if the PVC is now Bound:

```bash
kubectl get pvc -n operations
```

Check if a PV was dynamically created:

```bash
kubectl get pv
```

Check the Deployment and Pod:

```bash
kubectl get deployment -n operations
kubectl get pods -n operations
```

Wait for the pod to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=image-processor -n operations --timeout=60s
```

**Step 6: Verify the volume mount inside the pod**

Get the pod name:

```bash
POD_NAME=$(kubectl get pod -n operations -l app=image-processor -o jsonpath='{.items[0].metadata.name}')
echo $POD_NAME
```

Check if the /cache directory exists:

```bash
kubectl exec -n operations $POD_NAME -- ls -la /cache
```

Create a test file:

```bash
kubectl exec -n operations $POD_NAME -- sh -c 'echo "Storage test successful" > /cache/test.txt'
```

Read the test file:

```bash
kubectl exec -n operations $POD_NAME -- cat /cache/test.txt
```

Check disk usage:

```bash
kubectl exec -n operations $POD_NAME -- df -h /cache
```

**Step 7: Verify persistence (optional)**

Delete the pod and verify the data persists:

```bash
kubectl delete pod -n operations $POD_NAME
```

Wait for the new pod:

```bash
kubectl wait --for=condition=ready pod -l app=image-processor -n operations --timeout=60s
```

Get the new pod name:

```bash
NEW_POD_NAME=$(kubectl get pod -n operations -l app=image-processor -o jsonpath='{.items[0].metadata.name}')
```

Check if the file still exists:

```bash
kubectl exec -n operations $NEW_POD_NAME -- cat /cache/test.txt
```

**Verification checklist:**
- ✅ PVC `processor-cache` created in `operations` namespace
- ✅ PVC requests 1Gi storage with `local-path` StorageClass
- ✅ PVC status is `Bound`
- ✅ PV automatically created and bound to PVC
- ✅ Deployment manifest modified with volume and volumeMount
- ✅ Pod successfully mounts the volume at `/cache`
- ✅ Files can be created and read from `/cache`
- ✅ Data persists across pod restarts

</details>
