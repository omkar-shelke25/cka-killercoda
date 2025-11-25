# 🧠 **CKA: Storage Migration for Local Volumes**

📚 **Official Kubernetes Documentation**: 
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Volume Binding Mode](https://kubernetes.io/docs/concepts/storage/storage-classes/#volume-binding-mode)
- [Change Default StorageClass](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/)

### 🏢 **Context**

Your organization is migrating from Rancher's local-path storage to OpenEBS local storage for improved node-level volume management. The cluster currently has a default StorageClass named `local-storage`, but developers need a new OpenEBS-backed StorageClass for upcoming workloads.

You have been asked to prepare the cluster accordingly. The manifest you create must be stored at `/internal/openebs-local-sc.yaml`.



### ❓ **Question**

Create a new StorageClass named `openebs-local` that uses OpenEBS local provisioning with the following requirements: 
- the provisioner should be `openebs.io/local`, the volumeBindingMode should be `WaitForFirstConsumer`
- the reclaimPolicy should be `Delete`
- `allowVolumeExpansion` should be set to `true`. Include the field for driver-specific parameters. Save the manifest at `/internal/openebs-local-sc.yaml`.

After creating it, make `openebs-local` the new default StorageClass and ensure that the existing default StorageClass named `local-storage` is no longer marked as default. 

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Check existing StorageClasses**

First, examine the current StorageClasses in the cluster:
```bash
kubectl get storageclass
```

You should see `local-storage` marked as default.

**Step 2: Create the OpenEBS StorageClass manifest**

Create the StorageClass manifest at `/internal/openebs-local-sc.yaml`:

```bash
cat > /internal/openebs-local-sc.yaml <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-local
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    cas.openebs.io/config: |
      - name: StorageType
        value: "hostpath"
      - name: BasePath
        value: "/var/openebs/local"
provisioner: openebs.io/local
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
```

**Step 3: Verify the manifest**

```bash
cat /internal/openebs-local-sc.yaml
```

**Step 4: Remove default annotation from existing StorageClass**

Before applying the new StorageClass, remove the default annotation from the existing `local-storage` StorageClass:

```bash
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

Verify the change:
```bash
kubectl get storageclass local-storage -o jsonpath='{.metadata.annotations}'
```

**Step 5: Apply the new StorageClass**

```bash
kubectl apply -f /internal/openebs-local-sc.yaml
```

**Step 6: Verify the new default StorageClass**

Check that `openebs-local` is now the default:
```bash
kubectl get storageclass
```

You should see `openebs-local` marked with `(default)`.

Verify detailed configuration:
```bash
kubectl describe storageclass openebs-local
```

**Step 7: Confirm both StorageClasses exist**

```bash
kubectl get storageclass -o wide
```

Expected output should show:
- `local-storage` (not default)
- `openebs-local` (default)

</details>


