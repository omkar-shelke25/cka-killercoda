# 🧠 **CKA: Create Static Pod on Control Plane**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)

### 🏢 **Context**

After a long internal discussion, your team has decided to run `mcp-grafana` as a **static pod** on the control plane node.

The namespace `mcp-tool` has already been created for this purpose.

---

### 🎯 **Your Task**

You must create a static pod named `mcp-grafana` in the namespace `mcp-tool`. The pod must contain:

**Pod Configuration:**
- Pod name: `mcp-grafana`
- Namespace: `mcp-tool`
- Container name: `grafana`
- Image: `mcp/grafana:latest`
- Command: `["sh", "-c"]`
- Args: `["while true; do sleep 3600; done"]`
- Make sure the YAML file name is `mcp-grafana.yaml`

**Pod Labels:**
```yaml
app: mcp-grafana
tool: grafana
workload: monitoring
```

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the namespace exists**

```bash
kubectl get ns mcp-tool
```

**Step 2: Find the static pod directory**

```bash
grep staticPodPath /var/lib/kubelet/config.yaml
```

Output should show: `/etc/kubernetes/manifests`

**Step 3: Create the static pod manifest**

```bash
cat > /etc/kubernetes/manifests/mcp-grafana.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: mcp-grafana
  namespace: mcp-tool
  labels:
    app: mcp-grafana
    tool: grafana
    workload: monitoring
spec:
  containers:
  - name: grafana
    image: mcp/grafana:latest
    command: ["sh", "-c"]
    args: ["while true; do sleep 3600; done"]
EOF
```

**Step 4: Verify the static pod was created**

Wait a few seconds for kubelet to detect and create the pod:

```bash
# Check if pod is running
kubectl get pods -n mcp-tool
```

You should see a pod named `mcp-grafana-controlplane` (kubelet appends the node name).

**Step 5: Verify labels**

```bash
kubectl get pod -n mcp-tool -l app=mcp-grafana --show-labels
```

**Step 6: Check pod details**

```bash
kubectl describe pod -n mcp-tool mcp-grafana-controlplane
```

Verify:
- Container name is `grafana`
- Image is `mcp/grafana:latest`
- Command and args are correct
- All three labels are present

**Alternative: Generate manifest using kubectl**

You can also generate the manifest first and then copy it:

```bash
kubectl run mcp-grafana --image=mcp/grafana:latest --dry-run=client -o yaml \
  --command -- sh -c "while true; do sleep 3600; done" > /tmp/mcp-grafana.yaml
```

Then edit to add namespace and labels:

```bash
vi /tmp/mcp-grafana.yaml
```

Add:
```yaml
metadata:
  name: mcp-grafana
  namespace: mcp-tool
  labels:
    app: mcp-grafana
    tool: grafana
    workload: monitoring
```

Then copy to static pod directory:

```bash
cp /tmp/mcp-grafana.yaml /etc/kubernetes/manifests/
```

</details>

