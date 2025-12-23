# 🔒 **CKA: Analyze and Deploy NetworkPolicy**

📚 **Official Kubernetes Documentation**: 
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### 🏢 **Context**

You are the security engineer responsible for implementing network segmentation in a Kubernetes cluster. The development team has deployed frontend and backend applications in separate namespaces for isolation.

Your security team has prepared several NetworkPolicy YAML files, but you need to identify and deploy the **correct policy** that implements the principle of least privilege while ensuring the frontend can communicate with the backend.

There are two existing Deployments:
* **Frontend** in the namespace `frontend`
* **Backend** in the namespace `backend`

Several NetworkPolicy YAML files already exist in the directory: `/root/network-policies`

### ❓ **Problem Statement**

**Task:**
* Examine the NetworkPolicy YAML files in `/root/network-policies`
* Identify the NetworkPolicy that allows ingress traffic from the Frontend Pods to the Backend Pods
* The selected policy must allow **only the required communication** and must be the **least permissive**
* Deploy the selected NetworkPolicy to the cluster

**Requirements:**
* Frontend Pods must be able to communicate with Backend Pods
* Pods from any other namespace must **not** be allowed access to the Backend Pods
* No additional ports or Pod sources should be allowed
* Do not modify any existing Pods or Deployments

---

### 💡 **Analysis Guidelines**

<details><summary>🔍 What to Look For in NetworkPolicy Files</summary>

When analyzing NetworkPolicy files, check:

**1. Target Pod Selector**
```yaml
spec:
  podSelector:
    matchLabels:
      app: backend  # Should target backend pods
```

**2. Namespace Isolation**
```yaml
# Good - Specific namespace
from:
- namespaceSelector:
    matchLabels:
      name: frontend

# Bad - Allows all namespaces
from:
- podSelector: {}
```

**3. Port Restrictions**
```yaml
# Good - Only required port
ports:
- protocol: TCP
  port: 8080

# Bad - Multiple unnecessary ports
ports:
- protocol: TCP
  port: 8080
- protocol: TCP
  port: 443
- protocol: TCP
  port: 3000
```

**4. Policy Types**
```yaml
policyTypes:
- Ingress  # Should specify Ingress
```

</details>

<details><summary>🔍 Common NetworkPolicy Mistakes</summary>

**Mistake 1: Too Permissive - Empty podSelector**
```yaml
from:
- podSelector: {}  # Allows ALL pods in same namespace
```

**Mistake 2: Missing Namespace Selector**
```yaml
from:
- podSelector:
    matchLabels:
      app: frontend  # Only works in same namespace!
```

**Mistake 3: Allowing Unnecessary Ports**
```yaml
ports:
- protocol: TCP
  port: 8080
- protocol: TCP
  port: 443  # Not needed!
```

**Mistake 4: Too Restrictive**
```yaml
# Missing from clause - blocks all traffic
ingress:
- ports:
  - protocol: TCP
    port: 8080
# This allows traffic from ANY source!
```

</details>

<details><summary>🔍 Least Permissive Principle</summary>

The **least permissive** policy is one that:
1. ✅ Allows ONLY the required communication
2. ✅ Denies everything else by default
3. ✅ Uses specific selectors (not wildcards)
4. ✅ Specifies exact ports needed
5. ✅ Uses namespace selectors for cross-namespace traffic

**Example of Least Permissive:**
- Allows traffic from specific namespace (frontend)
- Allows traffic to specific pods (backend)
- Allows only required port (8080)
- No extra permissions

</details>

---

### 🧪 **Testing Your Solution**

After deploying the NetworkPolicy, verify it works correctly:

<details><summary>View testing commands</summary>

**1. Test from frontend namespace (should SUCCEED):**
```bash
FRONTEND_POD=$(kubectl get pod -n frontend -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n frontend $FRONTEND_POD -- curl -s --max-time 5 backend.backend.svc.cluster.local:8080
```

**2. Test from other namespace (should FAIL):**
```bash
OTHER_POD=$(kubectl get pod -n other -l app=other -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n other $OTHER_POD -- curl -s --max-time 5 backend.backend.svc.cluster.local:8080
```

**3. View deployed NetworkPolicy:**
```bash
kubectl get networkpolicy -n backend
kubectl describe networkpolicy backend-network-policy -n backend
```

**4. Check namespace labels:**
```bash
kubectl get namespaces --show-labels
```

</details>

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: List available NetworkPolicy files**

```bash
ls -l /root/network-policies/
```

You should see files like: `policy1.yaml`, `policy2.yaml`, `policy3.yaml`, etc.

**Step 2: Examine each NetworkPolicy file**

Let's analyze each policy:

```bash
echo "=== Policy 1 ==="
cat /root/network-policies/policy1.yaml
echo ""
echo "=== Policy 2 ==="
cat /root/network-policies/policy2.yaml
echo ""
echo "=== Policy 3 ==="
cat /root/network-policies/policy3.yaml
echo ""
echo "=== Policy 4 ==="
cat /root/network-policies/policy4.yaml
echo ""
echo "=== Policy 5 ==="
cat /root/network-policies/policy5.yaml
```

**Step 3: Analyze each policy**

Let's break down what each policy does:

**Policy 1 Analysis:**
```yaml
ingress:
- from:
  - podSelector: {}  # ❌ Allows ALL pods in backend namespace
    ports:
    - protocol: TCP
      port: 8080
```
**Verdict:** ❌ TOO PERMISSIVE - Empty podSelector allows all pods in the same namespace

**Policy 2 Analysis:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: frontend  # ✅ Only frontend namespace
    ports:
    - protocol: TCP
      port: 8080  # ✅ Only port 8080
```
**Verdict:** ✅ CORRECT - Least permissive, allows only frontend namespace to port 8080

**Policy 3 Analysis:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: frontend
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 443  # ❌ Unnecessary port
    - protocol: TCP
      port: 3000  # ❌ Unnecessary port
```
**Verdict:** ❌ TOO PERMISSIVE - Allows unnecessary ports (443, 3000)

**Policy 4 Analysis:**
```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend  # ❌ Only works within same namespace
    ports:
    - protocol: TCP
      port: 8080
```
**Verdict:** ❌ WRONG - podSelector without namespaceSelector only matches pods in the backend namespace. Frontend pods are in a different namespace!

**Policy 5 Analysis:**
```yaml
ingress:
- ports:
  - protocol: TCP
    port: 8080
  # ❌ No 'from' clause - allows from ANY source
```
**Verdict:** ❌ TOO PERMISSIVE - Missing `from` clause allows traffic from any source to port 8080

**Step 4: Verify namespace labels**

Before deploying, verify the frontend namespace has the correct label:

```bash
kubectl get namespace frontend --show-labels
```

You should see: `name=frontend` in the labels.

**Step 5: Deploy the correct NetworkPolicy (Policy 2)**

```bash
kubectl apply -f /root/network-policies/policy2.yaml
```

Verify it was created:
```bash
kubectl get networkpolicy -n backend
kubectl describe networkpolicy backend-network-policy -n backend
```

**Step 6: Test the NetworkPolicy**

**Test 1: Frontend should have access (PASS)**
```bash
echo "Test 1: Frontend to Backend (should SUCCEED)"
FRONTEND_POD=$(kubectl get pod -n frontend -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n frontend $FRONTEND_POD -- curl -s --max-time 5 backend.backend.svc.cluster.local:8080 | grep -o "<title>.*</title>"
```

Expected output: You should see the backend HTML title.

**Test 2: Other namespace should be blocked (FAIL)**
```bash
echo "Test 2: Other namespace to Backend (should FAIL)"
OTHER_POD=$(kubectl get pod -n other -l app=other -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n other $OTHER_POD -- curl -s --max-time 5 backend.backend.svc.cluster.local:8080 && echo "❌ ALLOWED (should be blocked)" || echo "✅ BLOCKED (correct)"
```

Expected output: Should timeout/fail (blocked by NetworkPolicy).

**Step 7: Understanding why Policy 2 is correct**

Policy 2 is the **least permissive** because:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend              # ✅ Targets only backend pods
  policyTypes:
  - Ingress                     # ✅ Controls incoming traffic
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend        # ✅ Only from frontend namespace
    ports:
    - protocol: TCP
      port: 8080                # ✅ Only port 8080
```

**Key Points:**
1. ✅ Uses `namespaceSelector` for cross-namespace traffic
2. ✅ Specifies only the frontend namespace using label
3. ✅ Allows only port 8080 (no extra ports)
4. ✅ Targets only backend pods
5. ✅ Implicitly denies all other traffic

**Step 8: View effective policy**

```bash
# Get policy in YAML format
kubectl get networkpolicy backend-network-policy -n backend -o yaml

# Check which pods are affected
kubectl get pods -n backend -l app=backend --show-labels

# Verify namespace labels
kubectl get namespace frontend --show-labels
```

**Verification checklist:**
- ✅ Correct NetworkPolicy identified (policy2.yaml)
- ✅ NetworkPolicy deployed to backend namespace
- ✅ Frontend pods can access backend on port 8080
- ✅ Other namespace pods CANNOT access backend
- ✅ Only port 8080 is allowed
- ✅ Policy uses namespaceSelector for cross-namespace traffic

</details>

---

### 🎯 **Quick Reference: Policy Comparison**

<details><summary>View comparison table</summary>

| Policy  | Namespace Selection | Port(s) | Verdict | Reason |
|---------|-------------------|---------|---------|--------|
| policy1 | ❌ Empty podSelector | 8080 | TOO PERMISSIVE | Allows all pods in backend namespace |
| policy2 | ✅ frontend namespace | 8080 | ✅ CORRECT | Least permissive, meets all requirements |
| policy3 | ✅ frontend namespace | 8080, 443, 3000 | TOO PERMISSIVE | Allows unnecessary ports |
| policy4 | ❌ podSelector only | 8080 | WRONG | Won't match frontend (different namespace) |
| policy5 | ❌ No from clause | 8080 | TOO PERMISSIVE | Allows from ANY source |

</details>

---

### 📝 **Additional Analysis Commands**

<details><summary>Useful commands for policy analysis</summary>

```bash
# Compare policies side by side
diff /root/network-policies/policy1.yaml /root/network-policies/policy2.yaml

# Search for namespaceSelector in policies
grep -n "namespaceSelector" /root/network-policies/*.yaml

# Count number of ports in each policy
for f in /root/network-policies/*.yaml; do 
  echo "$f: $(grep -c "port:" $f) ports"
done

# View all namespace labels
kubectl get namespaces --show-labels | grep -E "frontend|backend|other"

# Test connectivity before applying policy
FRONTEND_POD=$(kubectl get pod -n frontend -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n frontend $FRONTEND_POD -- curl -v backend.backend.svc.cluster.local:8080

# View pod labels
kubectl get pods -n backend --show-labels
kubectl get pods -n frontend --show-labels
```

</details>
