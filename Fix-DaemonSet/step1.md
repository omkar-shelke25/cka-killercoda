## 🔧 CKA Exam Question - Fix DaemonSet Scheduling

**Time Limit**: 6-8 minutes  
**Difficulty**: Medium  
**Points**: 6/100

---

### 📖 Problem Statement

The DaemonSet `fluentd-elasticsearch` in the `kube-system` namespace is not creating a pod on the control-plane node. 

Inspect and fix the issue so that the DaemonSet schedules a pod on every node in the cluster, including the control-plane.

The DaemonSet manifest is stored in the file at `/root/fluentd-elasticsearch.yaml`

### ✅ Solution (Try it yourself first!)

<details><summary>Click to view complete solution</summary>

#### Step 1: Investigate the Problem

```bash
# Check DaemonSet status
kubectl get daemonset fluentd-elasticsearch -n kube-system

# Output shows:
# DESIRED: 1 (only worker nodes)
# CURRENT: 1
# Missing: control-plane node

# Check nodes
kubectl get nodes

# Check control-plane taints
CONTROL_PLANE=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane)].metadata.name}' | awk '{print $1}')
kubectl describe node $CONTROL_PLANE | grep Taints

# Output:
# Taints: node-role.kubernetes.io/control-plane:NoSchedule
```

---

#### Step 2: Add Toleration to DaemonSet

```bash
# Edit the DaemonSet
kubectl edit daemonset fluentd-elasticsearch -n kube-system
```

Add the following toleration under `spec.template.spec`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:                                          # Add this section
      - key: node-role.kubernetes.io/control-plane         # Tolerate control-plane taint
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.0.4
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

Save and exit (`:wq` in vi/vim).

---

#### Step 3: Verify the Fix

```bash
# Check DaemonSet status (DESIRED should now equal total nodes)
kubectl get daemonset fluentd-elasticsearch -n kube-system

# Expected output:
# NAME                    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
# fluentd-elasticsearch   2         2         2       2            2

# Verify pods on all nodes
kubectl get pods -n kube-system -l name=fluentd-elasticsearch -o wide

# Should show pods on both control-plane and worker nodes

# Count verification
echo "Total nodes:"
kubectl get nodes --no-headers | wc -l

echo "Total fluentd pods:"
kubectl get pods -n kube-system -l name=fluentd-elasticsearch --no-headers | wc -l

# Both should be equal
```

---

#### Alternative: Apply Complete YAML

If you prefer, you can also apply the complete fixed YAML:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.0.4
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
EOF
```

---

#### Verification Commands

```bash
# Comprehensive check
echo "=== DaemonSet Status ==="
kubectl get daemonset fluentd-elasticsearch -n kube-system

echo -e "\n=== Pods on Nodes ==="
kubectl get pods -n kube-system -l name=fluentd-elasticsearch -o wide

echo -e "\n=== Node Count vs Pod Count ==="
echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "Pods: $(kubectl get pods -n kube-system -l name=fluentd-elasticsearch --no-headers | wc -l)"

echo -e "\n=== Pod Status ==="
kubectl get pods -n kube-system -l name=fluentd-elasticsearch -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
```

</details>
