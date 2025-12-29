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


**Given Information:**
- **Total node01 Allocated Resource:**
  - CPU: 1 core (1000m)
  - Memory: 1803.26171875 Mi

**Requirements:**
- The deployment will run **3 pods**
- Resources must be divided evenly across all 3 pods
- Add **20% overhead** to avoid node instability (reserve 20% for system processes)
- Both init containers and main containers must have **identical** resource requests and limits

**Calculation Steps:**

1. **Calculate available resources (after 20% system overhead):**
   ```
   Available CPU = 1000m × 0.8 = 800m
   Available Memory = 1803.26171875 Mi × 0.8 = 1442.609375 Mi
   ```

2. **Calculate per-pod resources (divide by 3 pods):**
   ```
   CPU per pod = 800m ÷ 3 = 266.67m
   Memory per pod = 1442.609375 Mi ÷ 3 = 480.869791667 Mi
   ```

3. **Round the values:**
   ```
   CPU: 266.67m → You can use 266m, 267m, or any value below (e.g., 250m, 200m)
   Memory: 480.87Mi → You can use 480Mi, 481Mi, or any value below (e.g., 450Mi, 400Mi)
   ```

4. **Maximum allowed resources per container:**
   - **CPU:** Must not exceed 267m (anything at or below is accepted)
   - **Memory:** Must not exceed 481Mi (anything at or below is accepted)

5. **Resources for each container:**
   - **init-setup container:** ≤ 267m CPU, ≤ 481Mi memory
   - **python-app container:** ≤ 267m CPU, ≤ 481Mi memory

**Note:** You can be conservative and allocate less than the calculated maximum. For example, 250m CPU and 450Mi memory would also be acceptable. The verification only checks that you don't exceed the calculated limits.


**Step 1: Scale down deployment**

```bash
kubectl scale deployment python-webapp -n python-ml-ns --replicas=0
```

Verify:
```bash
kubectl get deployment python-webapp -n python-ml-ns
kubectl get pods -n python-ml-ns
```

**Step 2: Calculate resources**

Given:
- Total CPU: 1000m, Total Memory: 1803.26171875 Mi
- System overhead: 20%, Number of pods: 3

```
Allocate node01 CPU = 1000m × 0.8 = 800m
Allocate node01 Memory = 1803.26171875 Mi × 0.8 = 1442.609375 Mi

Per Pod CPU = 800m ÷ 3 = 266.67m ≈ 266m (or 267m)
Per Pod Memory = 1442.609375 Mi ÷ 3 = 480.87 Mi ≈ 480Mi (or 481Mi)
```

**Step 3: Edit the deployment**

```bash
kubectl edit deployment python-webapp -n python-ml-ns
```

Add resources to **both containers**:
```yaml
resources:
  requests:
    cpu: 266m        # or 267m
    memory: 480Mi    # or 481Mi
  limits:
    cpu: 266m        # or 267m
    memory: 480Mi    # or 481Mi
```

**Step 4: Scale back to 3 replicas**

```bash
kubectl scale deployment python-webapp -n python-ml-ns --replicas=3
```

**Step 5: Verify pods are running**

```bash
kubectl get pods -n python-ml-ns
kubectl wait --for=condition=ready pod -l app=python-webapp -n python-ml-ns --timeout=120s
```

**Step 6: Verify resource configuration**

```bash
POD=$(kubectl get pod -n python-ml-ns -l app=python-webapp -o jsonpath='{.items[0].metadata.name}')

# Check init container resources
kubectl get pod $POD -n python-ml-ns -o jsonpath='{.spec.initContainers[0].resources}' | jq

# Check main container resources
kubectl get pod $POD -n python-ml-ns -o jsonpath='{.spec.containers[0].resources}' | jq

# Check QoS class (should be Guaranteed)
kubectl get pod $POD -n python-ml-ns -o jsonpath='{.status.qosClass}'
```

**Verification Checklist:**
- ✅ Deployment scaled to 0, then back to 3
- ✅ init-setup has resources configured
- ✅ python-app has resources configured
- ✅ Both containers have identical requests and limits
- ✅ All 3 pods are Running
- ✅ Pods have Guaranteed QoS class

</details>

