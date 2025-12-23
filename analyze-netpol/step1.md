# 🔒 **CKA: Analyze and Deploy NetworkPolicy**

📚 **Official Kubernetes Documentation**: 
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### 🏢 **Context**

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


</details>

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: List and examine available NetworkPolicy files**

```bash
ls -l /root/network-policies/
```

**Step 2: Analyze each policy**

Let's examine all policies:

```bash
for policy in /root/network-policies/policy*.yaml; do
  echo "=== $(basename $policy) ==="
  cat $policy
  echo ""
done
```

**Step 3: Detailed Policy Analysis**

**Policy 1 Analysis:**
```yaml
ingress:
- from:
  - podSelector: {}  # ❌ Empty selector
    ports:
    - protocol: TCP
      port: 8080
```
**Verdict:** ❌ **TOO PERMISSIVE**
- Empty `podSelector: {}` allows ALL pods in the backend namespace
- Doesn't restrict by namespace
- **Problem:** Any pod in backend namespace can access backend pods

---

**Policy 2 Analysis:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: frontend      # ✅ Selects frontend namespace
    podSelector:
      matchLabels:
        app: frontend       # ✅ Selects app=frontend pods
    ports:
    - protocol: TCP
      port: 8080           # ✅ Only required port
```
**Verdict:** ✅ **CORRECT - LEAST PERMISSIVE**
- Uses **BOTH** namespaceSelector AND podSelector
- Allows only pods that are:
  - In the `frontend` namespace AND
  - Have label `app=frontend`
- Only allows port 8080
- This is the **most restrictive** and **secure** option

---

**Policy 3 Analysis:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: frontend
    podSelector:
      matchLabels:
        app: frontend
  - ipBlock:               # ❌ Unnecessary external access
      cidr: 172.16.0.0/16
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 443            # ❌ Unnecessary port
```
**Verdict:** ❌ **TOO PERMISSIVE**
- Includes ipBlock which allows traffic from external IP range 172.16.0.0/16
- Allows multiple ports (8080 and 443)
- **Problem:** Opens backend to external network and unnecessary ports

---

**Policy 4 Analysis:**
```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        name: frontend     # ✅ Namespace selector present
    # ❌ Missing podSelector
    ports:
    - protocol: TCP
      port: 8080
```
**Verdict:** ❌ **TOO PERMISSIVE**
- Only has namespaceSelector, missing podSelector
- Allows **ALL pods** in the frontend namespace, not just `app=frontend` pods
- **Problem:** Any pod in frontend namespace can access backend (not least permissive)

---

**Policy 5 Analysis:**
```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend      # ❌ Only podSelector
    # ❌ Missing namespaceSelector
    ports:
    - protocol: TCP
      port: 8080
```
**Verdict:** ❌ **WRONG - WON'T WORK**
- Only has podSelector without namespaceSelector
- podSelector alone only matches pods in the **same namespace** (backend)
- **Problem:** Frontend pods are in a different namespace, so this won't allow them

---

**Step 4: Comparison Summary**

| Policy | namespaceSelector | podSelector | Ports | ipBlock | Verdict |
|--------|------------------|-------------|-------|---------|---------|
| policy1 | ❌ No | ❌ Empty {} | 8080 | No | Too Permissive |
| policy2 | ✅ Yes (frontend) | ✅ Yes (app=frontend) | 8080 | No | ✅ **CORRECT** |
| policy3 | ✅ Yes | ✅ Yes | 8080, 443 | ❌ Yes | Too Permissive |
| policy4 | ✅ Yes (frontend) | ❌ Missing | 8080 | No | Too Permissive |
| policy5 | ❌ No | ✅ Yes (app=frontend) | 8080 | No | Won't Work |

**Step 5: Deploy the correct NetworkPolicy (Policy 2)**

```bash
kubectl apply -f /root/network-policies/policy2.yaml
```

Verify deployment:
```bash
kubectl get networkpolicy -n backend
kubectl describe networkpolicy backend-network-policy -n backend
```

**Step 6: Verify namespace and pod labels**

```bash
# Check namespace labels
kubectl get namespace frontend --show-labels

# Check pod labels
kubectl get pods -n frontend --show-labels
kubectl get pods -n backend --show-labels
```

**Step 7: Test the NetworkPolicy**

**Test 1: Frontend should have access (PASS)**
```bash
echo "=== Test 1: Frontend to Backend (should SUCCEED) ==="
FRONTEND_POD=$(kubectl get pod -n frontend -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n frontend $FRONTEND_POD -- curl -s --max-time 5 backend.backend.svc.cluster.local:8080 | grep -o "<title>.*</title>"
```

**Test 2: Other namespace should be blocked (PASS)**
```bash
echo "=== Test 2: Other namespace to Backend (should FAIL) ==="
OTHER_POD=$(kubectl get pod -n other -l app=other -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n other $OTHER_POD -- curl -s --max-time 5 backend.backend.svc.cluster.local:8080 && echo "❌ ALLOWED" || echo "✅ BLOCKED (correct)"
```

**Step 8: Understanding why Policy 2 is correct**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend                    # Targets backend pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:              # ✅ Requirement 1: Namespace
        matchLabels:
          name: frontend
      podSelector:                    # ✅ Requirement 2: Specific pods
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080                      # ✅ Only required port
```

**Why this is the least permissive:**

1. ✅ **namespaceSelector + podSelector combined**: Source must be in frontend namespace AND have app=frontend label
2. ✅ **No ipBlock**: Doesn't allow external network access
3. ✅ **Single port**: Only allows port 8080, no extras
4. ✅ **Specific labels**: No empty selectors or wildcards
5. ✅ **Implicit deny**: Everything else is automatically blocked

**The key insight:** Using **both** `namespaceSelector` and `podSelector` in the **same from item** creates an AND condition, making it the most restrictive and secure option.

**Step 9: View the effective policy**

```bash
# Get full policy details
kubectl get networkpolicy backend-network-policy -n backend -o yaml

# Verify which pods are selected
kubectl get pods -n backend -l app=backend --show-labels

# Check ingress rules
kubectl get networkpolicy backend-network-policy -n backend -o jsonpath='{.spec.ingress[0].from}' | jq
```

**Verification checklist:**
- ✅ Policy 2 identified as correct (most restrictive)
- ✅ Deployed to backend namespace
- ✅ Uses BOTH namespaceSelector AND podSelector
- ✅ Frontend pods can access backend:8080
- ✅ Other namespace pods are blocked
- ✅ Only port 8080 allowed
- ✅ No ipBlock or external access
- ✅ Least permissive principle applied

</details>

