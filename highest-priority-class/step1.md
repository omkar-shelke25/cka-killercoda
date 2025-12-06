## 🛒 CKA Exam Question - PriorityClass Configuration

### 📚 Additional Resources

- [Kubernetes Pod Priority](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- [PriorityClass API Reference](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/priority-class-v1/)
- [Scheduling Best Practices](https://kubernetes.io/docs/concepts/scheduling-eviction/)


### 📖 Real-Life Context

Your organization, **AcmeRetail**, is preparing for its annual **Holiday Flash Sale**, a period when customer traffic increases sharply across all services. 

Several engineering teams have already created custom PriorityClasses to ensure that their mission-critical microservices continue to receive scheduling preference during heavy cluster load. 

System PriorityClasses such as `system-cluster-critical` and `system-node-critical` must be ignored when evaluating user-defined priorities.

A Deployment named `acme-log-forwarder`, running in the `priority` namespace, is responsible for collecting and forwarding transaction logs to the central SIEM platform during the event. 

To prevent delays or data loss, this workload must run with a priority just below AcmeRetail's highest user-defined PriorityClass.

---

### 🎯 Your Task

**1. Identify the highest existing user-defined PriorityClass value in the cluster.**  

**2. Create a new PriorityClass named `high-priority` whose `value` is one less than the highest user-defined PriorityClass.**  
   The PriorityClass must include:
   - `globalDefault: false`
   - `preemptionPolicy: PreemptLowerPriority`

**3. Update the Deployment `acme-log-forwarder` in the `priority` namespace so that its Pod spec uses this new PriorityClass.**

---

### 🔍 Investigation Phase

Start by examining what PriorityClasses already exist in the cluster.

```bash
# List all PriorityClasses
kubectl get priorityclasses

# View detailed information about each PriorityClass
kubectl get priorityclasses -o wide

# Get the value of a specific PriorityClass
kubectl get priorityclass <name> -o yaml
```

**Expected Output:**
```
NAME                      VALUE        GLOBAL-DEFAULT   AGE
payment-critical          1000000      false            5m
inventory-high            800000       false            5m
frontend-medium           500000       false            5m
analytics-low             100000       false            5m
system-cluster-critical   2000000000   false            30d
system-node-critical      2000001000   false            30d
```

**Analysis:**
- System PriorityClasses have very high values (2 billion+) → **Ignore these**
- User-defined PriorityClasses have values ranging from 100,000 to 1,000,000
- The highest user-defined value is **1,000,000** (payment-critical)
- Therefore, your new PriorityClass should have value: **999,999**

---

### 📝 Task 1: Create PriorityClass

Create a PriorityClass named `high-priority` with the following specifications:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: <one-less-than-highest-user-defined>
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "High priority for log forwarder during Holiday Flash Sale"
```

**Apply the PriorityClass:**
```bash
kubectl apply -f high-priority.yaml
```

**Verify it was created:**
```bash
kubectl get priorityclass high-priority
```

---

### 🔧 Task 2: Update Deployment

Update the `acme-log-forwarder` Deployment in the `priority` namespace to use the new PriorityClass.

**Option 1: Edit the Deployment directly**
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

**Option 3: Using kubectl set**
```bash
# Note: This method requires recreating the deployment
kubectl get deployment acme-log-forwarder -n priority -o yaml > deployment.yaml
# Edit deployment.yaml to add priorityClassName
kubectl apply -f deployment.yaml
```

---

### ✅ Verification

#### Verify PriorityClass
```bash
# Check PriorityClass exists
kubectl get priorityclass high-priority

# Verify the value is correct
kubectl get priorityclass high-priority -o yaml | grep -E 'value|globalDefault|preemptionPolicy'
```

**Expected output:**
```yaml
value: 999999
globalDefault: false
preemptionPolicy: PreemptLowerPriority
```

#### Verify Deployment Update
```bash
# Check if deployment has the PriorityClass
kubectl get deployment acme-log-forwarder -n priority -o yaml | grep priorityClassName

# Check the pods are using the new PriorityClass
kubectl get pods -n priority -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priorityClassName
```

**Expected output:**
```
NAME                                   PRIORITY
acme-log-forwarder-xxxxxxxxxx-xxxxx   high-priority
acme-log-forwarder-xxxxxxxxxx-xxxxx   high-priority
```

#### Check Pod Priority Value
```bash
# Verify pods have the correct priority value
kubectl get pods -n priority -o custom-columns=NAME:.metadata.name,PRIORITY-VALUE:.spec.priority
```

**Expected output:**
```
NAME                                   PRIORITY-VALUE
acme-log-forwarder-xxxxxxxxxx-xxxxx   999999
acme-log-forwarder-xxxxxxxxxx-xxxxx   999999
```
