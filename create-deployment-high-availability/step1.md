# 🎯 **CKA: Create Deployment with Pod Anti-Affinity**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Pod Affinity and Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity)

### 🏢 **Context**

The development team needs to deploy a high-availability application where no two Pods should run on the same worker node. This ensures that if a node fails, at least one Pod remains available on another node.

Since the cluster has only one worker node and the Deployment requests 2 replicas, the second Pod should remain in Pending state due to the anti-affinity rule.

---

### 🎯 **Your Task**

Implement the following in Namespace `project-tiger`:
* Create a Deployment named `deploy-important` with `2` replicas
* The Deployment and its Pods should have label `id=very-important`
* First container named `container1` with image `nginx:1-alpine`
* Second container named `container2` with image `google/pause`
* There should only ever be one Pod of that Deployment running on one worker node, use `topologyKey: kubernetes.io/hostname` for this


> Because there are one worker nodes and the Deployment has 2 replicas the result should be that the second Pod won't be scheduled.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Create the namespace**

```bash
kubectl create namespace project-tiger
```

**Step 2: Create the Deployment manifest**

Create the deployment YAML file:

```bash
vi deploy-important.yaml
```

**Step 3: Complete Deployment manifest**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-important
  namespace: project-tiger
  labels:
    id: very-important
spec:
  replicas: 2
  selector:
    matchLabels:
      id: very-important
  template:
    metadata:
      labels:
        id: very-important
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: id
                operator: In
                values:
                - very-important
            topologyKey: kubernetes.io/hostname
      containers:
      - name: container1
        image: nginx:1-alpine
      - name: container2
        image: google/pause
```

**Key Components Explained:**

1. **labels**: `id=very-important` on Deployment, selector, and Pod template
2. **replicas: 2**: Requests 2 Pod replicas
3. **podAntiAffinity**: Prevents Pods with the same label from scheduling on the same node
4. **requiredDuringSchedulingIgnoredDuringExecution**: Hard requirement (Pod won't schedule if rule can't be met)
5. **labelSelector**: Targets Pods with label `id=very-important`
6. **topologyKey: kubernetes.io/hostname**: Ensures uniqueness per node hostname
7. **Two containers**: container1 (nginx) and container2 (google/pause)

**Step 4: Apply the Deployment**

```bash
kubectl apply -f deploy-important.yaml
```

**Step 5: Verify the Deployment**

Check Deployment status:
```bash
kubectl get deployment -n project-tiger
```

Expected output:
```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
deploy-important   1/2     2            1           30s
```

Notice: Only 1/2 Pods are Ready (because only one worker node exists)

**Step 6: Check Pod status**

```bash
kubectl get pods -n project-tiger -o wide
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE   NODE
deploy-important-xxxxxxxxx-xxxxx   2/2     Running   0          30s   node01
deploy-important-xxxxxxxxx-xxxxx   0/2     Pending   0          30s   <none>
```

One Pod is Running on node01, the second is Pending (no node available due to anti-affinity)

**Step 7: Verify the Pending Pod reason**

Describe the Pending Pod:
```bash
kubectl describe pod -n project-tiger | grep -A 10 "Events:"
```

You should see an event like:
```
Warning  FailedScheduling  ... 0/2 nodes are available: 1 node(s) didn't match pod anti-affinity rules, 1 node(s) had taint {node-role.kubernetes.io/control-plane: }, that the pod didn't tolerate.
```

**Step 8: Verify Pod Anti-Affinity configuration**

```bash
kubectl get deployment deploy-important -n project-tiger -o jsonpath='{.spec.template.spec.affinity}' | jq
```

**Step 9: Verify both containers in Running Pod**

```bash
RUNNING_POD=$(kubectl get pod -n project-tiger --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $RUNNING_POD -n project-tiger -o jsonpath='{.spec.containers[*].name}'
```

Should output: `container1 container2`

**Step 10: Verify labels**

```bash
kubectl get deployment deploy-important -n project-tiger --show-labels
kubectl get pods -n project-tiger --show-labels
```

All should have label `id=very-important`

</details>

---
