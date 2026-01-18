# 🌐 **CKA: CoreDNS Configuration and Custom Domain**

📚 **Official Kubernetes Documentation**: 
- [Customizing DNS Service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [CoreDNS Documentation](https://coredns.io/manual/toc/)

### 🏢 **Context**

You are the cluster administrator responsible for DNS configuration. The development team needs to access services using a custom domain `killercoda.com` **alongside** the default `cluster.local` domain.

The CoreDNS configuration needs to be updated to support **both domains simultaneously**:
- `SERVICE.NAMESPACE.svc.cluster.local` (default - must continue working)
- `SERVICE.NAMESPACE.svc.killercoda.com` (custom - new requirement)

**Critical Requirement:** Both DNS domains must resolve to the **same services** at the **same time**. Services should be accessible via either domain.

### ❓ **Tasks**

#### **Task 1: Backup CoreDNS Configuration**

Make a backup of the existing CoreDNS configuration and store it at `/opt/course/16/coredns_backup.yaml`. The backup should be in a format that allows fast recovery.

#### **Task 2: Update CoreDNS Configuration**

Update the CoreDNS configuration in the cluster so that DNS resolution for `SERVICE.NAMESPACE.svc.killercoda.com` will work **alongside** and **in addition to** `SERVICE.NAMESPACE.svc.cluster.local`.

**Important:** Both domains must work simultaneously. Do NOT replace cluster.local - add killercoda.com as an additional domain.

#### **Task 3: Test DNS Resolution**

Test your configuration from a Pod with `busybox:1.35` image. **Both** of these commands should result in an IP address:

```bash
nslookup kubernetes.default.svc.cluster.local
nslookup kubernetes.default.svc.killercoda.com
```

**Expected Result:** Both commands should return the **same IP address**, proving both domains work simultaneously.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

# 🧩 Task 1: Backup CoreDNS Configuration

CoreDNS configuration is stored in a ConfigMap named **`coredns`** in the **`kube-system`** namespace.

### 📌 Step 1.1: Create a backup directory (if not already present)

```bash
mkdir -p /opt/course/16
```

### 📌 Step 1.2: Backup the CoreDNS ConfigMap

```bash
kubectl get configmap coredns -n kube-system -o yaml \
  > /opt/course/16/coredns_backup.yaml
```

✅ This YAML backup allows **fast recovery** using `kubectl apply -f`.

---

# 🧩 Task 2: Update CoreDNS Configuration (Add `killercoda.com`)

### 📌 Step 2.1: Edit the CoreDNS ConfigMap

```bash
kubectl edit configmap coredns -n kube-system
```

---

### 📌 Step 2.2: Modify the `Corefile`

Locate this **existing block** (it may already exist):

```text
kubernetes cluster.local in-addr.arpa ip6.arpa {
  pods insecure
  fallthrough in-addr.arpa ip6.arpa
  ttl 30
}
```

### 🔧 Replace it with this (ADD `killercoda.com`, do NOT remove `cluster.local`):

```text
kubernetes cluster.local killercoda.com in-addr.arpa ip6.arpa {
  pods insecure
  fallthrough in-addr.arpa ip6.arpa
  ttl 30
}
```

📌 **Why this works**

* CoreDNS now serves **two DNS zones**
* Both domains point to the **same Kubernetes service registry**
* `cluster.local` continues to work
* `killercoda.com` is added **in parallel**

Save and exit the editor.

---

### 📌 Step 2.3: Restart CoreDNS Pods

This forces CoreDNS to reload the updated configuration.

```bash
kubectl rollout restart deployment coredns -n kube-system
```

(Optional check)

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

Wait until all pods are `Running`.

---

# 🧩 Task 3: Test DNS Resolution

### 📌 Step 3.1: Start a BusyBox test Pod

```bash
kubectl run dns-test \
  --image=busybox:1.35 \
  --restart=Never \
  --command -- sleep 3600
```

---

### 📌 Step 3.2: Execute DNS lookups from the Pod

```bash
kubectl exec -it dns-test -- sh
```

Inside the pod, run:

```bash
nslookup kubernetes.default.svc.cluster.local
nslookup kubernetes.default.svc.killercoda.com
```

---

## ✅ Expected Output

* **Both commands return an IP address**
* **The IP addresses are identical**

Example:

```text
Address: 10.96.0.1
```

🎉 This confirms:

* Both domains work **simultaneously**
* Both resolve to the **same Kubernetes Service**
* The requirement is fully satisfied


</details>

