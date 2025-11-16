# 🧠 **CKA: Troubleshoot Pod Scheduling - Taints and Tolerations**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

### 🏢 **Context**

The API-backed Teams group has deployed an application called `mcp-postman` into the `mcp-inference` namespace. After deployment, the Pods created by this Deployment remain in the `Pending` state.

The Deployment manifest used by the team is stored at:
```bash
/test-api-backed/teams/mcp-inference.yaml
```

The team requirement is that `mcp-postman` **must run only on `node01`**.

---

### 🎯 **Your Task**

1. **Investigate** why the `mcp-postman` Pod is Pending. Use appropriate Kubernetes debugging commands (such as `kubectl describe pod`, `kubectl get events -n mcp-inference`) to identify the exact scheduling issue.

2. **Fix the issue** by editing the YAML file at the above path. While fixing, you must **NOT remove or modify**:
   * Existing labels
   * nodeAffinity section
   * Replicas count
   * Node's label
   * Container configuration

3. **Add the missing tolerations section** to ensure:
   * The Pod can tolerate the taint on `node01`
   * The toleration correctly matches the taint key, value, and effect
   * The Pod schedules correctly on `node01`

4. **Apply the fix** and verify that all Pod from the `mcp-postman` Deployment reaches the `Running` state on `node01`.

---


### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Investigate the issue**

Check Pod status:
```bash
kubectl get pods -n mcp-inference
```

Output shows Pods are Pending.

Describe a Pod to see the scheduling issue:
```bash
kubectl describe pod -n mcp-inference -l ai.model/name=mcp | grep -A 10 Events
```

You'll see an error like:
```
Warning  FailedScheduling  ... 0/2 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/mcp: true}, 1 node(s) didn't match Pod's node affinity/selector
```

Check the actual taint on node01:
```bash
kubectl describe node node01 | grep -A 2 Taints
```

Output:
```
Taints:             node-role.kubernetes.io/mcp=true:NoSchedule
```

**Step 2: Identify the problem**

The node has taint: `node-role.kubernetes.io/mcp=true:NoSchedule`

But the deployment YAML has **NO tolerations section** at all!

The Pod cannot schedule because it cannot tolerate the taint on node01.

**Step 3: Add the tolerations section**

Edit the deployment:
```bash
vi /test-api-backed/teams/mcp-inference.yaml
```

Add the `tolerations` section under `spec.template.spec` (before or after affinity):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-postman
  namespace: mcp-inference
  labels:
    app.kubernetes.io/name: mcp-postman
    app.kubernetes.io/component: mcp-test-runner
spec:
  replicas: 4
  selector:
    matchLabels:
      ai.model/type: llm
      ai.model/name: mcp  
  template:
    metadata:
      labels:
        ai.model/type: llm
        ai.model/name: mcp        
    spec:
      tolerations:
      - key: node-role.kubernetes.io/mcp
        effect: NoSchedule
        operator: Equal
        value: "true"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/mcp
                operator: Exists
      containers:
        - name: mcp-postman
          image: nginx:alpine
          command: ["sh", "-c", "while true; do sleep 3600; done"]
```

**Step 4: Apply the fix**

```bash
kubectl apply -f /test-api-backed/teams/mcp-inference.yaml
```

**Step 5: Verify Pods are running**

Wait for Pods to be ready:
```bash
kubectl rollout status deployment/mcp-postman -n mcp-inference
```

Check Pod status and node placement:
```bash
kubectl get pods -n mcp-inference -o wide
```

All 4 Pods should be Running on `node01`.

Verify the fix:
```bash
kubectl get pods -n mcp-inference -o wide | grep Running | grep node01 | wc -l
```

Should show: `4`

</details>

---
