# 🧠 **CKA: Troubleshoot kube-apiserver etcd Connection**

📚 **Official Kubernetes Documentation**: 
- [Operating etcd clusters](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- [kube-apiserver Configuration](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)
- [Troubleshooting Clusters](https://kubernetes.io/docs/tasks/debug/debug-cluster/)

### 🎯 **Scenario**

After a disaster recovery restore of a Kubernetes control plane, the kube-apiserver fails to start on the master node.

**Cluster background:**
- The etcd cluster is external and running in HA mode
- The disaster recovery restore process updated the kube-apiserver configuration
- kube-apiserver is currently configured to connect to etcd using port **2380**

**Problem:**
The cluster is completely inaccessible. All `kubectl` commands fail with connection errors.

### ❓ **Task**

1. **Determine** why the kube-apiserver cannot communicate with etcd
2. **Fix** the kube-apiserver configuration so it connects to the correct etcd endpoint
3. **Confirm** that the kube-apiserver is running and the cluster is accessible

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the problem - Test cluster connectivity**

```bash
kubectl get nodes
```

Expected output: Connection refused or timeout error

```bash
kubectl cluster-info
```

This will also fail, confirming the API server is down.

**Step 2: Check kube-apiserver container status**

```bash
# List all containers including stopped ones
sudo crictl ps -a | grep kube-apiserver
```

You might see the container restarting or in a failed state.

**Step 3: Check kube-apiserver logs**

```bash
# Get the container ID
APISERVER_ID=$(sudo crictl ps -a | grep kube-apiserver | awk '{print $1}' | head -n 1)

# View logs
sudo crictl logs $APISERVER_ID
```

Or use a one-liner:
```bash
sudo crictl logs $(sudo crictl ps -a | grep kube-apiserver | awk '{print $1}' | head -n 1) 2>&1 | tail -n 30
```

**Look for errors like:**
- `connection refused`
- `context deadline exceeded`
- `dial tcp :2380: connect: connection refused`
- References to port 2380

**Step 4: Understand etcd port configuration**

**Important: etcd has TWO different ports:**

| Port | Purpose | Used By |
|------|---------|---------|
| **2379** | Client connections | kube-apiserver, kubectl, etcdctl |
| **2380** | Peer communication | etcd cluster members only |

**The problem:** kube-apiserver is trying to connect to port **2380** (peer port) instead of **2379** (client port)

**Step 5: Examine the kube-apiserver manifest**

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -i etcd
```

Look for the `--etcd-servers` flag:
```bash
grep "etcd-servers" /etc/kubernetes/manifests/kube-apiserver.yaml
```

**You'll see something like:**
```yaml
- --etcd-servers=https://127.0.0.1:2380
```

**This is WRONG!** It should be port **2379**, not **2380**.

**Step 6: Fix the configuration**

**Method 1: Using sed (Quick fix)**

```bash
sudo sed -i 's/:2380/:2379/g' /etc/kubernetes/manifests/kube-apiserver.yaml
```

**Method 2: Manual editing**

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Find the line with `--etcd-servers` and change:
```yaml
# BEFORE (WRONG - peer port)
- --etcd-servers=https://127.0.0.1:2380

# AFTER (CORRECT - client port)
- --etcd-servers=https://127.0.0.1:2379
```

Save and exit (`:wq` in vi).

**Step 7: Verify the fix**

```bash
grep "etcd-servers" /etc/kubernetes/manifests/kube-apiserver.yaml
```

Should now show port **2379**.

**Step 8: Wait for kubelet to restart the pod**

The kubelet watches the `/etc/kubernetes/manifests/` directory and will automatically restart the static pod.

```bash
# Watch for the container to restart
watch "sudo crictl ps | grep kube-apiserver"
```

Or check periodically:
```bash
sudo crictl ps | grep kube-apiserver
```

Wait about 30-60 seconds for the pod to start.

**Step 9: Monitor the kube-apiserver startup**

```bash
# Watch logs in real-time
sudo crictl logs -f $(sudo crictl ps | grep kube-apiserver | awk '{print $1}')
```

Press Ctrl+C to stop watching.

**Step 10: Verify cluster is accessible**

```bash
kubectl get nodes
```

Should now work and show your nodes!

```bash
kubectl cluster-info
```

Should show cluster information.

```bash
kubectl get pods -A
```

Should list all pods across all namespaces.

**Step 11: Check component health**

```bash
kubectl get componentstatuses
```

Note: This is deprecated but might still work in some clusters.

Better approach:
```bash
kubectl get pods -n kube-system
```

All system pods should be running.

</details>
