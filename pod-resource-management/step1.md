## 🧮 Configure Pod Resource Management for Python Application

📚 **Official Kubernetes Documentation**: [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

You are managing a Python web application running in a Kubernetes cluster. The application is currently deployed without proper resource configuration, which could lead to instability.

---

### 🎯 Your Tasks:

#### Task 1: Scale Down the Deployment

Scale down the `python-webapp` deployment in the `default` namespace to **0 replicas** to safely make configuration changes.

---

#### Task 2: Calculate Resource Allocation

**Important:** Before editing the deployment, you need to calculate the correct resource values.

**Requirements:**
- The deployment will run **3 pods**
- Resources must be divided **evenly** across all 3 pods
- Add **20% overhead** to avoid node instability (reserve 20% for system processes)
- **Both init containers and main containers** must have **identical** resource requests and limits

#### Task 3: Edit the Deployment

Edit the `python-webapp` deployment and add resource requests and limits to **both** the init container (`init-setup`) and the main container (`python-app`).

**Requirements:**
- Add `resources` section to **both containers**
- Use the values you calculated in Task 2
- `requests` and `limits` must be **identical** (guaranteed QoS)
- Both init container and main container must have the **same** resource values


#### Task 4: Scale Back to 3 Replicas

After successfully editing the deployment, scale it back to **3 replicas**.



> Note: Round DOWN to nearest whole number for safety


### ✅ Solution (Try it yourself first!)

<details><summary>Click to view complete solution</summary>




#### Step 1: Check Node Resources

```bash
kubectl describe node | grep -A 5 "Allocatable:"
```

**Expected output:**
```
Allocatable:
  cpu:                1
  memory:             1803Mi
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
Memory Overhead = 1803Mi × 0.20 = 360.6Mi → 361Mi

Step 2 - Available:
Available CPU = 1000m - 200m = 800m
Available Memory = 1803Mi - 361Mi = 1442Mi

Step 3 - Per Pod:
CPU per Pod = 800m ÷ 3 = 266.67m → 266m (round down)
Memory per Pod = 1442Mi ÷ 3 = 480.67Mi → 480Mi (round down)

Final Values:
- CPU: 266m
- Memory: 480Mi
```


<details><summary>Another Example calculation (not the actual answer)</summary>

**Example with fictional values:**
```
Given: 2000m CPU, 2000Mi Memory, 3 pods, 20% overhead

Step 1: Calculate overhead
CPU Overhead = 2000m × 0.20 = 400m
Memory Overhead = 2000Mi × 0.20 = 400Mi

Step 2: Available resources
Available CPU = 2000m - 400m = 1600m
Available Memory = 2000Mi - 400Mi = 1600Mi

Step 3: Per pod (÷3)
CPU per Pod = 1600m ÷ 3 = 533.33m → 533m (round down)
Memory per Pod = 1600Mi ÷ 3 = 533.33Mi → 533Mi (round down)
```
</details>
---

#### Step 3: Scale Down

```bash
kubectl scale deployment python-webapp --replicas=0 -n default
```

Verify:
```bash
kubectl get deployment python-webapp -n default
```

---

#### Step 4: Edit Deployment

```bash
kubectl edit deployment python-webapp -n default
```

**Add the following resources to BOTH containers:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-webapp
  namespace: default
spec:
  replicas: 0
  selector:
    matchLabels:
      app: python-webapp
  template:
    metadata:
      labels:
        app: python-webapp
    spec:
      initContainers:
      - name: init-setup
        image: busybox:1.28
        command: ['sh', '-c', 'echo "Initializing Python application..." && sleep 2']
        resources:
          requests:
            cpu: "266m"
            memory: "480Mi"
          limits:
            cpu: "266m"
            memory: "480Mi"
      containers:
      - name: python-app
        image: python:3.11-slim
        command: ['python', '-c']
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          import os
          
          class Handler(BaseHTTPRequestHandler):
              def do_GET(self):
                  self.send_response(200)
                  self.send_header('Content-Type', 'application/json')
                  self.end_headers()
                  
                  data = {
                      'app': 'Python Web Application',
                      'status': 'running',
                      'version': '1.0',
                      'message': 'Hello from Kubernetes!',
                      'pod': os.environ.get('HOSTNAME', 'unknown')
                  }
                  
                  self.wfile.write(json.dumps(data, indent=2).encode())
          
          print('Starting Python web server on port 8080...')
          server = HTTPServer(('0.0.0.0', 8080), Handler)
          server.serve_forever()
        resources:
          requests:
            cpu: "266m"
            memory: "480Mi"
          limits:
            cpu: "266m"
            memory: "480Mi"
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: PYTHONUNBUFFERED
          value: "1"
```

Save and exit (`:wq` in vim)

---

#### Step 5: Verify Configuration

```bash
# Check deployment configuration
kubectl get deployment python-webapp -n default -o yaml | grep -A 8 "resources:"
```

Expected output (should appear twice - once for init, once for main):
```yaml
        resources:
          limits:
            cpu: 266m
            memory: 480Mi
          requests:
            cpu: 266m
            memory: 480Mi
```

---

#### Step 6: Scale Back to 3 Replicas

```bash
kubectl scale deployment python-webapp --replicas=3 -n default
```

---

#### Step 7: Final Verification

```bash
# 1. Check all pods are running
kubectl get pods -l app=python-webapp -n default

# Expected: 3 pods in Running state

# 2. Verify resource configuration
kubectl describe pod -l app=python-webapp -n default | grep -A 8 "Limits:"

# 3. Check node allocation
kubectl describe node | grep -A 10 "Allocated resources:"

# Expected: Around 798m CPU (266m × 3) and 1440Mi memory (480Mi × 3)

# 4. Test the application
kubectl run test-curl --image=curlimages/curl -i --rm --restart=Never -- \
  curl -s http://python-webapp.default.svc.cluster.local
```

---

#### Alternative: Using kubectl patch

```bash
# Scale down
kubectl scale deployment python-webapp --replicas=0 -n default

# Patch with calculated resources
kubectl patch deployment python-webapp -n default --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/0/resources",
    "value": {
      "requests": {"cpu": "266m", "memory": "480Mi"},
      "limits": {"cpu": "266m", "memory": "480Mi"}
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/resources",
    "value": {
      "requests": {"cpu": "266m", "memory": "480Mi"},
      "limits": {"cpu": "266m", "memory": "480Mi"}
    }
  }
]'

# Scale back up
kubectl scale deployment python-webapp --replicas=3 -n default
```

</details>

