# Step 5: Install Pod Network (CNI Plugin) 🌐

## 📚 Documentation Reference
- [Installing a Pod network add-on](https://kubernetes.io/docs/concepts/cluster-administration/addons/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/)
- [Flannel Documentation](https://github.com/flannel-io/flannel)

## 🎯 Objective

Install a Container Network Interface (CNI) plugin to enable pod-to-pod communication across the cluster. You'll choose between Calico (production-grade) or Flannel (simpler).

## 🧠 Why This Matters

Without a CNI plugin:
- Pods cannot communicate with each other
- Nodes remain in `NotReady` state
- No cluster networking is available

CNI provides:
- Pod IP address management
- Network policy enforcement (Calico)
- Cross-node pod communication

---

## 📋 Choose Your CNI Plugin

### Option A: Calico (Recommended for Production) ⭐

**Advantages:**
- Network policy support
- Better scalability
- Advanced networking features
- Production-ready

**Installation steps:**

1. Install Calico operator:

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
```

2. Download custom resources manifest:

```bash
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O
```

3. Apply the custom resources:

```bash
kubectl create -f custom-resources.yaml
```

4. Watch Calico pods until all are running:

```bash
watch kubectl get pods -n calico-system
```

⏱️ **Wait**: 2-3 minutes for all pods to reach `Running` state

Press `Ctrl+C` to exit watch once all pods are running.

---

### Option B: Flannel (Simpler Alternative) 🚀

**Advantages:**
- Simpler architecture
- Faster installation
- Good for testing/learning
- Lower resource usage

**Installation steps:**

1. Apply Flannel manifest:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

2. Watch until pods are running:

```bash
watch kubectl get pods -n kube-flannel
```

⏱️ **Wait**: 1-2 minutes for pods to reach `Running` state

Press `Ctrl+C` to exit watch once pods are running.

---

## 📋 Post-Installation Tasks

### Verify CNI Installation

Check CNI pods are running:

**For Calico:**
```bash
kubectl get pods -n calico-system
```

**For Flannel:**
```bash
kubectl get pods -n kube-flannel
```

All pods should show `Running` status.

---

### Verify Node Status Changed to Ready

Check node status:

```bash
kubectl get nodes
```

Expected output:
```
NAME          STATUS   ROLES           AGE   VERSION
controlplane  Ready    control-plane   10m   v1.34.0
```

✅ **Status should now be `Ready`!**

Check more details:

```bash
kubectl get nodes -o wide
```

This shows IP addresses, container runtime, and OS information.

---

### Verify System Pods are Running

Check all kube-system pods:

```bash
kubectl get pods -n kube-system
```

Expected output: All pods should be in `Running` state:
- kube-apiserver
- kube-controller-manager
- kube-scheduler
- kube-proxy
- coredns (2 replicas)
- etcd

---

## ✅ Verification Checklist

Before proceeding, ensure:

- [ ] CNI plugin is installed (Calico or Flannel)
- [ ] All CNI pods are in `Running` state
- [ ] Node status changed from `NotReady` to `Ready`
- [ ] CoreDNS pods are running (2 replicas)
- [ ] All kube-system pods are healthy

---

## 🔍 Troubleshooting

**Problem**: Node still shows `NotReady` after 5 minutes
- **Solution**: Check CNI pod logs:
  ```bash
  kubectl logs -n calico-system -l k8s-app=calico-node
  # or for Flannel:
  kubectl logs -n kube-flannel -l app=flannel
  ```

**Problem**: CNI pods in `CrashLoopBackOff`
- **Solution**: 
  - Verify pod network CIDR matches init: `192.168.0.0/16`
  - Check: `kubectl cluster-info dump | grep cluster-cidr`
  - If mismatch, you may need to reinitialize

**Problem**: CoreDNS pods pending
- **Solution**: This is normal until CNI is fully running
- Wait 2-3 more minutes and check again

**Problem**: "connection refused" errors
- **Solution**: Ensure API server is healthy:
  ```bash
  kubectl get --raw /healthz
  ```

---

## 📝 What You Learned

- Container Network Interface (CNI) concept
- Differences between Calico and Flannel
- Pod networking architecture
- Network policy capabilities (Calico)
- Troubleshooting network plugin issues

---

## 🎓 Advanced Concepts (Optional Reading)

**Network Policies:**
With Calico, you can create network policies to control pod communication:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**IPAM (IP Address Management):**
- Calico uses BGP for routing
- Flannel uses VXLAN overlay network
- Both manage pod IP allocation automatically

---

**Ready?** Click **Continue** to proceed to Step 6! ➡️
