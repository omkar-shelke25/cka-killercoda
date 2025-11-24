# 🧠 **CKA: Recover API Server from Certificate Deletion**

📚 **Official Kubernetes Documentation**: 
- [PKI Certificates and Requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
- [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)

### 🔥 **Context**

Your company uses an automated script to rotate Kubernetes control-plane certificates every 365 days. Due to a bug in a recent update, the automation deleted the API server TLS files `/etc/kubernetes/pki/apiserver.crt` and `/etc/kubernetes/pki/apiserver.key` instead of renewing them.

At first, everything seemed fine because the kube-apiserver was still running with the certificates already loaded in memory. However, later that night, a routine node security patch caused kubelet to restart, which triggered all static pods—including the kube-apiserver—to restart.

After the restart, the kube-apiserver container failed to start and is stuck in a CrashLoopBackOff state. `kubectl` no longer works from any node or admin workstation.

You have SSH access to the control-plane node and full sudo privileges.

### ❓ **Question**

Your task is to restore the Kubernetes API server to full operational status. Regenerate the missing API server certificate and key using kubeadm, restart the API server successfully, and verify that kubectl functionality has been restored. The cluster should be fully operational with all control plane components running.

Do not manually create certificates using OpenSSL or other tools—use kubeadm's built-in certificate management commands. Do not modify any other cluster resources or configurations beyond what is necessary to complete the recovery.

---

### 🔍 **Investigation Commands**

Before fixing, investigate the problem:

```bash
# Check if certificates are missing
sudo ls -la /etc/kubernetes/pki/apiserver.*

# Check API server container status
sudo crictl ps -a | grep kube-apiserver

# View API server logs
sudo crictl logs $(sudo crictl ps -a --name kube-apiserver -q | head -n 1) 2>&1 | tail -20

# Check static pod manifest
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 2 "tls-cert-file"
```

---

### Try it yourself first!

<details><summary>💡 Hint 1: Certificate Generation Tool</summary>

`kubeadm` has built-in commands for certificate management. Look into:
```bash
kubeadm certs --help
```

The `kubeadm certs renew` command can regenerate certificates even if they're missing.

</details>

<details><summary>💡 Hint 2: Which Certificate to Renew</summary>

The missing files are:
- `apiserver.crt`
- `apiserver.key`

Use:
```bash
sudo kubeadm certs renew apiserver
```

This regenerates the API server serving certificate.

</details>

<details><summary>💡 Hint 3: Restarting the API Server</summary>

After regenerating certificates, the API server needs to reload them. Since it's a static pod, you can:

**Option 1:** Move the manifest temporarily
```bash
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sleep 10
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

**Option 2:** Delete the container (kubelet will recreate it)
```bash
sudo crictl rm -f $(sudo crictl ps -a --name kube-apiserver -q)
```

</details>

---

<details><summary>✅ Solution (expand to view)</summary>

### **Step 1: Verify the Problem**

```bash
# Confirm certificates are missing
sudo ls -la /etc/kubernetes/pki/apiserver.crt
sudo ls -la /etc/kubernetes/pki/apiserver.key
```

Expected output: `No such file or directory`

```bash
# Check API server is failing
sudo crictl ps -a | grep kube-apiserver
```

You should see the container repeatedly restarting or in Error state.

```bash
# View error logs
sudo crictl logs $(sudo crictl ps -a --name kube-apiserver -q | head -n 1) 2>&1 | tail -20
```

Look for errors about missing certificate files.

---

### **Step 2: Regenerate the API Server Certificate**

```bash
# Use kubeadm to regenerate the apiserver certificate
sudo kubeadm certs renew apiserver
```

Expected output:
```
certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself renewed
```

Verify the files are recreated:
```bash
sudo ls -la /etc/kubernetes/pki/apiserver.crt
sudo ls -la /etc/kubernetes/pki/apiserver.key
```

---

### **Step 3: Restart the API Server**

**Method 1: Temporarily move the static pod manifest**

```bash
# Move manifest out (stops the pod)
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Wait for the pod to be removed
sleep 10

# Move manifest back (starts the pod)
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

**Method 2: Force remove the container (simpler)**

```bash
# Get container ID and remove it
sudo crictl rm -f $(sudo crictl ps -a --name kube-apiserver -q)
```

The kubelet will automatically recreate the container with the new certificates.

---

### **Step 4: Wait for API Server to Start**

```bash
# Watch the API server come up
watch "sudo crictl ps | grep kube-apiserver"
```

Wait until the status shows `Running` (press `Ctrl+C` to exit watch).

Alternatively:
```bash
# Check status every few seconds
for i in {1..30}; do
  sudo crictl ps | grep kube-apiserver && break
  echo "Waiting for API server... ($i/30)"
  sleep 2
done
```

---

### **Step 5: Verify Cluster Functionality**

```bash
# Test kubectl
kubectl get nodes
```

Expected output: Node should be in `Ready` state.

```bash
# Check all control plane pods
kubectl get pods -n kube-system
```

All pods should be `Running`.

```bash
# Verify API server is healthy
kubectl get --raw /healthz
```

Expected output: `ok`

```bash
# Check certificate expiry
sudo kubeadm certs check-expiration | grep apiserver
```

---

### **Step 6: Additional Verification**

```bash
# Test API server endpoints
kubectl get componentstatuses 2>/dev/null || kubectl get cs 2>/dev/null || echo "Component status API deprecated but cluster working"

# Create a test resource
kubectl run test-pod --image=nginx --rm -it --restart=Never -- echo "API working"

# View API server logs
sudo crictl logs $(sudo crictl ps --name kube-apiserver -q) 2>&1 | tail -30
```

---

### **📋 Verification Checklist**

- ✅ `/etc/kubernetes/pki/apiserver.crt` exists and is recent
- ✅ `/etc/kubernetes/pki/apiserver.key` exists and is recent
- ✅ kube-apiserver container is in `Running` state
- ✅ `kubectl get nodes` returns successfully
- ✅ All kube-system pods are running
- ✅ API health endpoint returns `ok`

---

### **🔧 Troubleshooting Tips**

**If API server still won't start:**

1. Check all certificates are present:
```bash
sudo kubeadm certs check-expiration
```

2. Verify kubelet is running:
```bash
sudo systemctl status kubelet
```

3. Check for port conflicts:
```bash
sudo netstat -tulpn | grep 6443
```

4. Review detailed API server logs:
```bash
sudo journalctl -u kubelet -f
```

**If kubectl still doesn't work:**

1. Verify kubeconfig is valid:
```bash
kubectl config view
```

2. Test direct API access:
```bash
curl -k https://localhost:6443/healthz
```

3. Regenerate admin kubeconfig if needed:
```bash
sudo kubeadm init phase kubeconfig admin
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
```

</details>
