# 🧠 **CKA: Install and Configure Calico CNI**

📚 **Official Kubernetes Documentation**: 
- [Installing Addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)
- [Network Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Project Calico Documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/)

### 🏢 **Context**

Your organization is preparing a dev enviroment cluster, single-node Kubernetes cluster.

The cluster has already been initialized successfully using `kubeadm.`

A background automation script provisions the control-plane node only (no worker nodes).

> Wait for 2 minutes for the Kubernetes cluster setup. Use the command below to verify whether the cluster is ready.

- `crictl ps`   
- `kubectl get no`

> Make Sure Commponents is running 


### ❓ **Tasks**

Due to security, compliance, and tenant isolation requirements, your task is to install Project Calico as the Container Network Interface (CNI) plugin because it supports Kubernetes NetworkPolicy enforcement.

You are provided with the official Tigera Operator manifest:

```
https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml
```

Complete the following tasks to deploy Calico CNI on your Kubernetes cluster:

1. **Install Calico using the Tigera Operator**
   - Apply the Tigera Operator manifest from the provided URL
   - Wait for the operator to be fully deployed

2. **Configure Calico to use the existing Pod CIDR of the cluster**
   - Create an Installation custom resource to configure Calico
   - Ensure Calico uses this CIDR for pod networking.

3. **Verify that:**
   - Calico system components are running successfully
   - All nodes are in `Ready` state
   - The cluster can enforce Kubernetes `NetworkPolicy` objects.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify cluster is ready**

First, check that the cluster initialization is complete:

```bash
kubectl get nodes
kubectl get pods -A
```

You should see the control plane node, but it will be in `NotReady` state until the CNI is installed.

---

**Step 2: Install the Tigera Operator**

Apply the Tigera Operator manifest:

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml
```

Wait for the operator to be ready:

```bash
kubectl wait --for=condition=ready pod -l k8s-app=tigera-operator -n tigera-operator --timeout=300s
```

Verify the operator is running:

```bash
kubectl get pods -n tigera-operator
```

---

**Step 3: Create the Installation custom resource**

Find podCIDR for node:

```bash
kubectl describe node | grep -i podcidr
```

Alternative:

```bash
kubectl -n kube-system get cm kubeadm-config | grep -i podsubnet
```

Copy the tigera-operator URL mentioned in the question and remove `tigera-operator.yaml`, then use `custom-resources.yaml`

```bash
https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml
```

```bash
wget https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/custom-resources.yaml
```

The Installation CR configures Calico. Create it with the correct Pod CIDR:

```bash
kubectl create -f - <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF
```

**Explanation of the configuration:**

* `cidr: 10.244.0.0/16` - Matches the cluster's Pod CIDR
* `blockSize: 26` - Each node gets a /26 subnet (64 IPs)
* `encapsulation: VXLANCrossSubnet` - Uses VXLAN for cross-subnet traffic
* `natOutgoing: Enabled` - NAT for traffic leaving the cluster

---

**Step 4: Wait for Calico to be deployed**

Monitor the installation progress:

```bash
watch kubectl get tigerastatus
```

Wait until you see `Available: True` for all components. Press `Ctrl+C` to exit watch.

Alternatively, check with:

```bash
kubectl get tigerastatus -w
```

---

**Step 5: Verify Calico system components**

Check that all Calico pods are running:

```bash
kubectl get pods -n calico-system
```

You should see pods like:

* `calico-kube-controllers`
* `calico-node`
* `calico-typha` (if present)

Check the API server pods:

```bash
kubectl get pods -n calico-apiserver
```

---

**Step 6: Verify nodes are Ready**

```bash
kubectl get nodes
```

The node should now be in `Ready` state. If not, wait a minute and check again.

Check node details:

```bash
kubectl describe node | grep -A 5 "Conditions:"
```


*Below Steps are optinal* 

**Step 7: Test NetworkPolicy enforcement**

Create a test namespace:

```bash
kubectl create namespace policy-test
```

Deploy two test pods:

```bash
kubectl run frontend --image=nginx --namespace=policy-test
kubectl run backend --image=nginx --namespace=policy-test
```

Wait for pods to be ready:

```bash
kubectl wait --for=condition=ready pod -l run=frontend -n policy-test --timeout=60s
kubectl wait --for=condition=ready pod -l run=backend -n policy-test --timeout=60s
```

Test connectivity (should work initially):

```bash
kubectl exec -n policy-test frontend -- curl -s --max-time 5 backend
```

Create a NetworkPolicy that blocks all ingress traffic:

```bash
kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: policy-test
spec:
  podSelector:
    matchLabels:
      run: backend
  policyTypes:
  - Ingress
EOF
```

Test connectivity again (should fail now):

```bash
kubectl exec -n policy-test frontend -- curl -s --max-time 5 backend || echo "✅ NetworkPolicy is working! Connection blocked as expected."
```

Create a policy to allow traffic from frontend:

```bash
kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: policy-test
spec:
  podSelector:
    matchLabels:
      run: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          run: frontend
    ports:
    - protocol: TCP
      port: 80
EOF
```

Test connectivity again (should work now):

```bash
kubectl exec -n policy-test frontend -- curl -s --max-time 5 backend
```

**Step 8: Final verification checklist**

```bash
echo "=== Node Status ==="
kubectl get nodes

echo ""
echo "=== Calico System Pods ==="
kubectl get pods -n calico-system

echo ""
echo "=== Calico API Server ==="
kubectl get pods -n calico-apiserver

echo ""
echo "=== Tigera Status ==="
kubectl get tigerastatus

echo ""
echo "=== NetworkPolicy Test ==="
kubectl get networkpolicy -n policy-test
```

</details>


