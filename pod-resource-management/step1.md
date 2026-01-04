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
 

#### Task 3: Edit the Deployment

Edit the `python-webapp` deployment and add resource requests and limits to **both** the init container (`init-setup`) and the main container (`python-app`).

After successfully editing the deployment, scale it back to **3 replicas**.

Verify that all 3 pods are in `Running` state and have the correct resource configuration:



### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

# Kubernetes Resource Configuration - Imperative Commands

## 📊 Given Information

**Total `node01` Allocatable Resource:**
- **CPU:** 1 core (1000m)
- **Memory:** 1948940Ki ÷ 1024 = **1803.26171875 Mi**

**Currently Allocated Resources (by other workloads):**
- **CPU:** 125m (12%)
- **Memory:** 100Mi (5%)

## 📋 Requirements

- The deployment will run **3 pods**
- Resources must be divided evenly across all 3 pods
- Add **20% overhead** to avoid node instability (reserve 20% for system processes)
- Both init containers and main containers must have **identical** resource requests and limits

---

## 🧮 Calculation Steps

### **1. Calculate available resources (after 20% system overhead):**

```
Available CPU = 1000m × 0.8 = 800m
Available Memory = 1803.26171875 Mi × 0.8 = 1442.609375 Mi
```

### **2. Subtract currently allocated resources:**

```
CPU remaining = 800m - 125m = 675m
Memory remaining = 1442.609375 Mi - 100Mi = 1342.609375 Mi
```

### **3. Calculate per-pod resources (divide by 3 pods):**

```
CPU per pod = 675m ÷ 3 = 225m
Memory per pod = 1342.609375 Mi ÷ 3 = 447.536458333 Mi
```

### **4. Round the values:**

```
CPU: 225m → You can use 225m or any value below (e.g., 200m, 150m)
Memory: 447.54Mi → You can use 447Mi, 448Mi, or any value below (e.g., 400Mi, 350Mi)
```

### **5. Maximum allowed resources per container:**

- **CPU:** Must not exceed 225m (anything at or below is accepted)
- **Memory:** Must not exceed 448Mi (anything at or below is accepted)

### **6. Resources for each container:**

- **init-setup container:** ≤ 225m CPU, ≤ 448Mi memory
- **python-app container:** ≤ 225m CPU, ≤ 448Mi memory

---

## 🛠️ Implementation Steps (Imperative Commands)

### **Step 1: Scale down deployment**

```bash
kubectl scale deployment python-webapp -n python-ml-ns --replicas=0
```

**Verify:**
```bash
kubectl get deployment python-webapp -n python-ml-ns
kubectl get pods -n python-ml-ns
```

---

### **Step 2: Calculate resources**

**Given:**
- Total CPU: 1000m, Total Memory: 1803.26171875 Mi
- Currently allocated: CPU 125m, Memory 100Mi
- System overhead: 20%, Number of pods: 3

**Calculation:**
```
Allocate node01 CPU = 1000m × 0.8 = 800m
Allocate node01 Memory = 1803.26171875 Mi × 0.8 = 1442.609375 Mi

Subtract allocated CPU = 800m - 125m = 675m
Subtract allocated Memory = 1442.609375 Mi - 100Mi = 1342.609375 Mi

Per Pod CPU = 675m ÷ 3 = 225m
Per Pod Memory = 1342.609375 Mi ÷ 3 = 447.54 Mi ≈ 447Mi (or 448Mi)
```

---

### **Step 3: Set resources using imperative commands**

```bash
kubectl set resources deployment python-webapp \
  -n python-ml-ns \
  --requests=cpu=225m,memory=447Mi \
  --limits=cpu=225m,memory=447Mi
```

---

### **Step 4: Scale back to 3 replicas**

```bash
kubectl scale deployment python-webapp -n python-ml-ns --replicas=3
```

---

### **Step 5: Verify pods are running**

```bash
kubectl get pods -n python-ml-ns
```

```bash
kubectl wait --for=condition=ready pod -l app=python-webapp -n python-ml-ns --timeout=120s
```

**Expected output:** All 3 pods with status `Running` and `READY 1/1`

---

### **Step 6: Verify resource configuration**

```bash
POD=$(kubectl get pod -n python-ml-ns -l app=python-webapp -o jsonpath='{.items[0].metadata.name}')

# Check init container resources
kubectl get pod $POD -n python-ml-ns -o jsonpath='{.spec.initContainers[0].resources}' | jq

# Check main container resources
kubectl get pod $POD -n python-ml-ns -o jsonpath='{.spec.containers[0].resources}' | jq

# Check QoS class (should be Guaranteed)
kubectl get pod $POD -n python-ml-ns -o jsonpath='{.status.qosClass}'
```

**Expected output:**
```json
{
  "limits": {
    "cpu": "225m",
    "memory": "447Mi"
  },
  "requests": {
    "cpu": "225m",
    "memory": "447Mi"
  }
}
```

QoS Class: `Guaranteed`

---

## 📝 Alternative: Single-line Commands

**Scale down:**
```bash
kubectl scale deployment python-webapp -n python-ml-ns --replicas=0
```

**Set resources for main container:**
```bash
kubectl set resources deployment python-webapp -n python-ml-ns --containers=python-app --requests=cpu=225m,memory=447Mi --limits=cpu=225m,memory=447Mi
```

**Set resources for init container:**
```bash
kubectl set resources deployment python-webapp -n python-ml-ns --containers=init-setup --requests=cpu=225m,memory=447Mi --limits=cpu=225m,memory=447Mi
```

**Scale up:**
```bash
kubectl scale deployment python-webapp -n python-ml-ns --replicas=3
```

**Verify:**
```bash
kubectl get pods -n python-ml-ns -w
```

---

## ✅ Verification Checklist

- ✅ Deployment scaled to 0, then back to 3
- ✅ init-setup has resources configured
- ✅ python-app has resources configured
- ✅ Both containers have identical requests and limits
- ✅ All 3 pods are Running
- ✅ Pods have Guaranteed QoS class
- ✅ Resources per container: ≤ 225m CPU, ≤ 448Mi memory

---

## 📊 Final Resource Allocation Summary

| Resource Type | Calculation | Value |
|---------------|-------------|-------|
| **Total Allocatable CPU** | - | 1000m |
| **After 20% overhead** | 1000m × 0.8 | 800m |
| **Minus allocated** | 800m - 125m | 675m |
| **Per pod** | 675m ÷ 3 | **225m** |
| | | |
| **Total Allocatable Memory** | - | 1803.26 Mi |
| **After 20% overhead** | 1803.26 Mi × 0.8 | 1442.61 Mi |
| **Minus allocated** | 1442.61 Mi - 100Mi | 1342.61 Mi |
| **Per pod** | 1342.61 Mi ÷ 3 | **447 Mi** |

**Total for 3 pods:** 675m CPU, 1341Mi Memory  
**Remaining on node:** 125m CPU, ~101Mi Memory


</details>

