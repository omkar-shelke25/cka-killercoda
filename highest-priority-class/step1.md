## 🛒 CKA Exam Question - PriorityClass Configuration

### 📚 Additional Resources

- [Kubernetes Pod Priority](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- [PriorityClass API Reference](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/priority-class-v1/)
- [Scheduling Best Practices](https://kubernetes.io/docs/concepts/scheduling-eviction/)


### 📖 Real-Life Context

Your organization, **AcmeRetail**, is preparing for its annual **Holiday Flash Sale**, a period when customer traffic increases sharply across all services. 

Several engineering teams have already created custom PriorityClasses to ensure that their mission-critical microservices continue to receive scheduling preference during heavy cluster load. 

A Deployment named `acme-log-forwarder`, running in the `priority` namespace, is responsible for collecting and forwarding transaction logs to the central SIEM platform during the event. 

---

### 🎯 Your Task

**1. Identify the highest existing user-defined PriorityClass value in the cluster.**  

**2. Create a new PriorityClass named `high-priority` whose `value` is one less than the highest user-defined PriorityClass.**  
   The PriorityClass must include:
   - `globalDefault: false`
   - `preemptionPolicy: PreemptLowerPriority`

**3. Update the Deployment `acme-log-forwarder` in the `priority` namespace so that its Pod spec uses this new PriorityClass.**

### ✅ Solution (Try it yourself first!)

<details><summary>Click to view complete solution</summary>

#### Step 1: Investigate Existing PriorityClasses

```bash
# List all PriorityClasses
kubectl get priorityclasses

# View with values
kubectl get priorityclasses --no-headers | awk '{print $1, $2}'

# Get detailed info for each user-defined class
kubectl get priorityclass payment-critical -o yaml
kubectl get priorityclass inventory-high -o yaml
kubectl get priorityclass frontend-medium -o yaml
kubectl get priorityclass analytics-low -o yaml
```

**Analysis:**
```
NAME                      VALUE
payment-critical          1000000    ← Highest user-defined
inventory-high            800000
frontend-medium           500000
analytics-low             100000
system-cluster-critical   2000000000 ← Ignore (system class)
system-node-critical      2000001000 ← Ignore (system class)
```

**Conclusion:** 
- Highest user-defined value: 1,000,000
- Your value should be: 999,999 (one less)

---

#### Step 2: Create PriorityClass

```bash
cat > /tmp/high-priority.yaml <<'EOF'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 999999
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "High priority for log forwarder during Holiday Flash Sale"
EOF

# Apply the PriorityClass
kubectl apply -f /tmp/high-priority.yaml
```

**Verify PriorityClass:**
```bash
# Check it was created
kubectl get priorityclass high-priority

# View details
kubectl get priorityclass high-priority -o yaml
```

---

#### Step 3: Update Deployment

**Option 1: Using kubectl edit**
```bash
kubectl edit deployment acme-log-forwarder -n priority
```

Add `priorityClassName: high-priority` under `spec.template.spec`:
```yaml
spec:
  template:
    spec:
      priorityClassName: high-priority  # Add this line
      containers:
      - name: forwarder
        image: python:3.11-slim
        # ... rest of config
```

**Option 2: Using kubectl patch**
```bash
kubectl patch deployment acme-log-forwarder -n priority \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/priorityClassName", "value": "high-priority"}]'
```

**Option 3: Using kubectl set (alternative)**
```bash
# Get current deployment
kubectl get deployment acme-log-forwarder -n priority -o yaml > /tmp/deployment.yaml

# Edit the file to add priorityClassName under spec.template.spec

# Apply changes
kubectl apply -f /tmp/deployment.yaml
```

---

#### Step 4: Verify Configuration

```bash
# Check deployment has priorityClassName
kubectl get deployment acme-log-forwarder -n priority -o yaml | grep priorityClassName

# Check pods are using the PriorityClass
kubectl get pods -n priority -o custom-columns=NAME:.metadata.name,PRIORITY-CLASS:.spec.priorityClassName

# Verify priority value
kubectl get pods -n priority -o custom-columns=NAME:.metadata.name,PRIORITY-VALUE:.spec.priority
```

**Expected Output:**
```
NAME                                   PRIORITY-CLASS
acme-log-forwarder-xxxxxxxxxx-xxxxx   high-priority
acme-log-forwarder-xxxxxxxxxx-xxxxx   high-priority

NAME                                   PRIORITY-VALUE
acme-log-forwarder-xxxxxxxxxx-xxxxx   999999
acme-log-forwarder-xxxxxxxxxx-xxxxx   999999
```

---

#### Step 5: Verify Priority Hierarchy

```bash
# View all PriorityClasses sorted by value
kubectl get priorityclasses --sort-by=.value

# View just user-defined classes
kubectl get priorityclasses --no-headers | grep -v system | sort -k2 -n
```

**Final Hierarchy:**
```
NAME                VALUE
analytics-low       100000
frontend-medium     500000
inventory-high      800000
high-priority       999999   ← Your new class
payment-critical    1000000  ← Highest user-defined
```

---

#### Verification Commands

```bash
# Complete verification
echo "Checking PriorityClass..."
kubectl get priorityclass high-priority -o yaml | grep -E "value|globalDefault|preemptionPolicy"

echo -e "\nChecking Deployment..."
kubectl get deployment acme-log-forwarder -n priority -o jsonpath='{.spec.template.spec.priorityClassName}'

echo -e "\nChecking Pods..."
kubectl get pods -n priority -l app=log-forwarder -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority,PRIORITY-CLASS:.spec.priorityClassName
```

</details>
