## 🧮 Configure Pod Resource Management for Python ML Application

📚 **Official Kubernetes Documentation**: [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

You are managing a Python Machine Learning web application running in a Kubernetes cluster. The application is currently deployed without proper resource configuration, which could lead to instability and resource contention.

---

### 🎯 Your Tasks:

#### Task 1: Scale Down the Deployment

Scale down the `python-webapp` deployment in the `python-ml-ns` namespace to **0 replicas** to safely make configuration changes.


#### Task 2: Calculate Resource Allocation

**Important:** Before editing the deployment, you need to calculate the correct resource values.

**Requirements:**
- The deployment will run **3 pods**
- Resources must be divided **evenly** across all 3 pods
- Add **20% overhead** to avoid node instability (reserve 20% for system processes)
- **Both init containers and main containers** must have **identical** resource requests and limits.

> Note: Only round down to the nearest whole number for safety.
 

#### Task 3: Edit the Deployment

Edit the `python-webapp` deployment and add resource requests and limits to **both** the init container (`init-setup`) and the main container (`python-app`).

After successfully editing the deployment, scale it back to **3 replicas**.

Verify that all 3 pods are in `Running` state and have the correct resource configuration:


### ✅ Solution (Try it yourself first!)

<details><summary>Click to view complete solution</summary>

There is a taint on the control plane node, so we cannot use its resources. We use only node01 resources.

#### Step 1: Check Node Resources

```bash
kubectl describe node node01 | grep -A 5 "Allocatable:"
```

**Expected output:**
```
Allocatable:
  cpu:                1
  memory:             1846656Ki/1024Ki=1803.375Mi=1803Mi (round down)
```

**Note:** `1` CPU = `1000m` (millicores)

---

#### Step 2: Calculate Resources

```
Given:
- Total CPU: 1000m (1 core)
- Total Memory: 1803Mi
- Overhead: 20%
- Number of Pods: 3

Calculation:
Step 1 - Overhead:
CPU Overhead = 1000m × 0.20 = 200m
Memory Overhead = 1803Mi × 0.20 = 360.6Mi → 360Mi (round-down)

Step 2 - Available:
Available CPU = 1000m - 200m = 800m
Available Memory = 1803Mi - 360Mi = 1443Mi

Step 3 - Per Pod:
CPU per Pod = 800m ÷ 3 = 266.67m → 266m (round down)
Memory per Pod = 1443Mi ÷ 3 = 481Mi (round down)

Final Values:
- CPU: 266m
- Memory: 481Mi
```

---

#### Step 3: Scale Down

```bash
kubectl scale deployment python-webapp --replicas=0 -n python-ml-ns
```

Verify:
```bash
kubectl get deployment python-webapp -n python-ml-ns
```

---

#### Step 4: Edit Deployment

```bash
kubectl edit deployment python-webapp -n python-ml-ns
```

**Add the following resources to BOTH containers:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-webapp
  namespace: python-ml-ns
spec:
  replicas: 0
  selector:
    matchLabels:
      app: python-webapp
  template:
    metadata:
      labels:
        app: python-webapp
        tier: ml-service
    spec:
      initContainers:
      - name: init-setup
        image: busybox:1.28
        command: ['sh', '-c', 'echo "🔧 Initializing ML environment..." && sleep 2 && echo "✅ Initialization complete"']
        resources:
          requests:
            cpu: "266m"
            memory: "481Mi"
          limits:
            cpu: "266m"
            memory: "481Mi"
      containers:
      - name: python-app
        image: python:3.11-slim
        command: ['python', '/app/app.py']
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: PYTHONUNBUFFERED
          value: "1"
        - name: APP_ENV
          value: "production"
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          requests:
            cpu: "266m"
            memory: "481Mi"
          limits:
            cpu: "266m"
            memory: "481Mi"
      volumes:
      - name: app-code
        configMap:
          name: python-app-code
```

Save and exit (`:wq` in vim)

---

#### Step 5: Verify Configuration

```bash
# Check deployment configuration
kubectl get deployment python-webapp -n python-ml-ns -o yaml | grep -A 8 "resources:"
```

Expected output (should appear twice - once for init, once for main):
```yaml
        resources:
          limits:
            cpu: 266m
            memory: 481Mi
          requests:
            cpu: 266m
            memory: 481Mi
```

---

#### Step 6: Scale Back to 3 Replicas

```bash
kubectl scale deployment python-webapp --replicas=3 -n python-ml-ns
```

---

#### Step 7: Final Verification

```bash
# 1. Check all pods are running
kubectl get pods -l app=python-webapp -n python-ml-ns

# Expected: 3 pods in Running state

# 2. Verify resource configuration
kubectl describe pod -l app=python-webapp -n python-ml-ns | grep -A 8 "Limits:"

# 3. Check node allocation
kubectl describe node | grep -A 10 "Allocated resources:"

# Expected: Around 798m CPU (266m × 3) and 1443Mi memory (481Mi × 3)

# 4. Test the application
kubectl run test-curl --image=curlimages/curl -i --rm --restart=Never -n python-ml-ns -- \
  curl -s http://python-webapp.python-ml-ns.svc.cluster.local
```

---

#### Alternative: Using kubectl patch

```bash
# Scale down
kubectl scale deployment python-webapp --replicas=0 -n python-ml-ns

# Patch with calculated resources
kubectl patch deployment python-webapp -n python-ml-ns --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/0/resources",
    "value": {
      "requests": {"cpu": "266m", "memory": "481Mi"},
      "limits": {"cpu": "266m", "memory": "481Mi"}
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/resources",
    "value": {
      "requests": {"cpu": "266m", "memory": "481Mi"},
      "limits": {"cpu": "266m", "memory": "481Mi"}
    }
  }
]'

# Scale back up
kubectl scale deployment python-webapp --replicas=3 -n python-ml-ns
```

</details>

