# Step 6: Join Worker Nodes to Cluster 👷

## 📚 Documentation Reference
- [kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/)
- [Adding worker nodes](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#join-nodes)

## 🎯 Objective

Learn how to join worker nodes to your Kubernetes cluster using the join command generated during cluster initialization.

## 🧠 Why This Matters

Worker nodes:
- Run application workloads (pods)
- Execute tasks scheduled by the control plane
- Provide compute resources for the cluster
- Enable horizontal scaling

---

## 📝 Note About This Environment

> ⚠️ **Important**: This Killercoda environment provides a single node setup. You won't actually join worker nodes here, but you'll learn the complete process for multi-node production clusters.

> You can deploy any pod to verify that it is running correctly

In a real multi-node setup, you would:
1. Complete Steps 1-3 on each worker node
2. Run the join command on each worker
3. Verify nodes are added to the cluster

---

## 📋 Tasks (Conceptual for Single-Node Environment)

### Task 6.1: Retrieve the Join Command

If you saved the output from Step 4, you have the join command. If not, generate a new one:

**On the master node:**

```bash
kubeadm token create --print-join-command
```

This outputs something like:
```bash
kubeadm join 192.168.1.100:6443 --token abc123.xyz789 \
    --discovery-token-ca-cert-hash sha256:abcd1234ef567890...
```

💡 **Save this command** - you'll run it on each worker node.

---

### Task 6.2: Understanding the Join Command

Let's break down the components:

```bash
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

**Parameters:**
- `<MASTER_IP>:6443`: API server address and port
- `--token`: Authentication token (expires in 24 hours)
- `--discovery-token-ca-cert-hash`: CA certificate hash for security

---

### Task 6.3: Manual Token and Hash Retrieval (Advanced)

If you need to construct the join command manually:

**Get the token:**
```bash
kubeadm token list
```

**Create a new token if needed:**
```bash
kubeadm token create
```

**Get the CA certificate hash:**
```bash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
   openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
```

**Construct the join command:**
```bash
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN_FROM_LIST> \
  --discovery-token-ca-cert-hash sha256:<HASH_FROM_ABOVE>
```

---

### Task 6.4: Worker Node Prerequisites

Before joining, ensure each worker node has:

✅ Steps 1-3 completed:
- System prepared (swap disabled, modules loaded)
- Container runtime installed (containerd)
- Kubernetes components installed (kubeadm, kubelet, kubectl)

🔴 **DO NOT run `kubeadm init` on worker nodes** - only on the master!

---

### Task 6.5: Execute Join Command (On Worker Nodes)

**On each worker node, run:**

```bash
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Expected output:
```
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

---

### Task 6.6: Verify Worker Nodes (On Master)

Check nodes from the master:

```bash
kubectl get nodes
```

Expected output with workers:
```
NAME          STATUS   ROLES           AGE   VERSION
controlplane  Ready    control-plane   20m   v1.31.0
worker-1      Ready    <none>          2m    v1.31.0
worker-2      Ready    <none>          1m    v1.31.0
```

Get detailed information:

```bash
kubectl get nodes -o wide
```

This shows IP addresses, OS, kernel, and container runtime for each node.

---

### Task 6.7: Label Worker Nodes (Optional)

Add meaningful labels to worker nodes:

```bash
kubectl label node worker-1 node-role.kubernetes.io/worker=worker
```

Now `kubectl get nodes` will show the worker role:
```
NAME          STATUS   ROLES           AGE   VERSION
controlplane  Ready    control-plane   20m   v1.31.0
worker-1      Ready    worker          2m    v1.31.0
```

---

## ✅ Verification Checklist

In a multi-node setup, ensure:

- [ ] Join command is available
- [ ] Prerequisites completed on all worker nodes
- [ ] Join command executed successfully on each worker
- [ ] All nodes show `Ready` status
- [ ] All nodes show correct version
- [ ] Worker nodes appear in `kubectl get nodes`

---

## 🔍 Troubleshooting

**Problem**: "connection refused" to API server
- **Solution**: 
  - Verify master IP is correct
  - Check firewall allows port 6443
  - Ensure API server is running: `kubectl get pods -n kube-system`

**Problem**: "unauthorized: Token has expired"
- **Solution**: Generate new token on master:
  ```bash
  kubeadm token create --print-join-command
  ```

**Problem**: Node joins but stays `NotReady`
- **Solution**: 
  - Wait 2-3 minutes for CNI to configure networking
  - Check CNI pods: `kubectl get pods -n calico-system` or `kubectl get pods -n kube-flannel`

**Problem**: "unable to fetch the kubeadm-config ConfigMap"
- **Solution**: Ensure control plane is healthy:
  ```bash
  kubectl get pods -n kube-system
  ```

**Problem**: Certificate errors
- **Solution**: Verify the CA cert hash is correct
- Regenerate: See Task 6.3

---
**Excellent work!** Even in this single-node environment, you now understand the complete multi-node join process! 🎉

Click **Continue** to proceed to Step 7: Final Verification! ➡️
