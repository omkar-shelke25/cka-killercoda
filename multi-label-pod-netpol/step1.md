# 🔒 **CKA: Configure NetworkPolicy with Multi-Label Selection**

📚 **Official Kubernetes Documentation**: 
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### 🏢 **Context**

You are the security engineer for a microservices platform running in Kubernetes. The security team has identified that the API service in the `isolated` namespace requires strict access controls.

The API service (labeled `app=api`) handles sensitive data and must only be accessible from the frontend proxy pods that have been properly authenticated and authorized. These pods must have BOTH the `app=frontend` AND `role=proxy` labels to ensure they're legitimate proxy instances.

Several test pods have been deployed to verify your NetworkPolicy configuration:
- `api-pod` - API service on port 7000 (should be protected)
- `api-pod-alt` - API service on port 8080 (should be blocked)
- `frontend-proxy-pod` - Has both required labels (should have access)
- `frontend-only-pod` - Missing `role=proxy` label (should NOT have access)
- `database-pod` - Different application (should NOT have access)

### ❓ **Problem Statement**

Create a new NetworkPolicy named `allow-multi-pod-ingress` in the existing namespace `isolated`.

The NetworkPolicy should allow incoming traffic to Pods with label `app=api` in namespace `isolated` only if **ALL** of the following conditions are met:

* Traffic originates from Pods with label `app=frontend`
* Traffic originates from Pods with label `role=proxy`
* Traffic is directed to TCP port 7000
* Pods that do not listen on port 7000 must not be accessible
* Pods other than those with label `app=api` must not be allowed access
* Pods that do not match the above source Pod labels must not be allowed access

**Requirements:**
- NetworkPolicy name: `allow-multi-pod-ingress`
- Namespace: `isolated`
- Target pods: `app=api`
- Allowed source pods: Must have BOTH `app=frontend` AND `role=proxy` labels
- Allowed port: TCP 7000 only
- Default behavior: Deny all other ingress traffic to the API pods

---

### 💡 **Important Concepts**

<details><summary>🔍 Understanding NetworkPolicy Label Selectors</summary>

NetworkPolicy supports two types of label matching:

**1. podSelector (single selector)**
```yaml
podSelector:
  matchLabels:
    app: frontend
```
This matches pods with the `app=frontend` label.

**2. matchLabels with multiple labels (AND logic)**
```yaml
podSelector:
  matchLabels:
    app: frontend
    role: proxy
```
This matches pods that have BOTH labels - it's an AND operation, not OR.

**Key Point**: When multiple labels are specified in `matchLabels`, a pod must have ALL of them to match!

</details>

<details><summary>🔍 NetworkPolicy Ingress Rules</summary>

An ingress rule consists of:
- **from**: Defines source pods/namespaces/IP blocks
- **ports**: Defines allowed ports and protocols

Example structure:
```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        key: value
  ports:
  - protocol: TCP
    port: 8080
```

</details>

<details><summary>🔍 Default Deny Behavior</summary>

When you create a NetworkPolicy that selects a pod:
- The pod becomes isolated for the policy type (Ingress/Egress)
- Only traffic explicitly allowed by NetworkPolicies is permitted
- All other traffic is denied by default

This is why specifying the `policyTypes` and rules is crucial!

</details>

---

### 🧪 **Testing Your Solution**

After creating the NetworkPolicy, verify it works correctly:

<details><summary>View testing commands</summary>

**1. Test from frontend-proxy-pod (should SUCCEED - has both labels):**
```bash
kubectl exec -n isolated frontend-proxy-pod -- curl -s --max-time 3 api-pod:7000
```
Expected: Should return HTML content from api-pod

**2. Test from frontend-only-pod (should FAIL - missing role=proxy):**
```bash
kubectl exec -n isolated frontend-only-pod -- curl -s --max-time 3 api-pod:7000
```
Expected: Should timeout (no response)

**3. Test from database-pod (should FAIL - wrong labels):**
```bash
kubectl exec -n isolated database-pod -- curl -s --max-time 3 api-pod:7000
```
Expected: Should timeout (no response)

**4. Test port 8080 on api-pod-alt (should FAIL - wrong port):**
```bash
kubectl exec -n isolated frontend-proxy-pod -- curl -s --max-time 3 api-pod-alt:8080
```
Expected: Should timeout (port 8080 not allowed)

**5. View NetworkPolicy details:**
```bash
kubectl describe networkpolicy allow-multi-pod-ingress -n isolated
```

</details>

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Understand the requirements**

We need to create a NetworkPolicy that:
- Selects target pods with label `app=api`
- Allows ingress traffic ONLY from pods with BOTH labels: `app=frontend` AND `role=proxy`
- Allows traffic ONLY to port 7000 TCP
- Denies all other ingress traffic (implicit)

**Step 2: Create the NetworkPolicy**

Create the NetworkPolicy using kubectl:

```bash
kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-multi-pod-ingress
  namespace: isolated
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
          role: proxy
    ports:
    - protocol: TCP
      port: 7000
EOF
```

**Alternative method using YAML file:**

```bash
cat > networkpolicy.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-multi-pod-ingress
  namespace: isolated
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
          role: proxy
    ports:
    - protocol: TCP
      port: 7000
EOF

kubectl apply -f networkpolicy.yaml
```

**Step 3: Verify the NetworkPolicy was created**

```bash
kubectl get networkpolicy -n isolated
kubectl describe networkpolicy allow-multi-pod-ingress -n isolated
```

**Step 4: Test the NetworkPolicy**

**Test 1: From frontend-proxy-pod (should work - has both labels)**
```bash
echo "Test 1: frontend-proxy-pod to api-pod:7000 (should SUCCEED)"
kubectl exec -n isolated frontend-proxy-pod -- curl -s --max-time 3 api-pod:7000 | grep -o "<title>.*</title>" || echo "BLOCKED"
```

**Test 2: From frontend-only-pod (should fail - missing role=proxy)**
```bash
echo "Test 2: frontend-only-pod to api-pod:7000 (should FAIL)"
kubectl exec -n isolated frontend-only-pod -- curl -s --max-time 3 api-pod:7000 && echo "ALLOWED" || echo "BLOCKED ✓"
```

**Test 3: From database-pod (should fail - wrong labels)**
```bash
echo "Test 3: database-pod to api-pod:7000 (should FAIL)"
kubectl exec -n isolated database-pod -- curl -s --max-time 3 api-pod:7000 && echo "ALLOWED" || echo "BLOCKED ✓"
```

**Test 4: To port 8080 on api-pod-alt (should fail - wrong port)**
```bash
echo "Test 4: frontend-proxy-pod to api-pod-alt:8080 (should FAIL)"
kubectl exec -n isolated frontend-proxy-pod -- curl -s --max-time 3 api-pod-alt:8080 && echo "ALLOWED" || echo "BLOCKED ✓"
```

**Step 5: Understanding the configuration**

Let's break down the NetworkPolicy YAML:

```yaml
spec:
  podSelector:
    matchLabels:
      app: api                    # Applies to pods with label app=api
  policyTypes:
  - Ingress                       # This is an ingress policy (incoming traffic)
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend           # Source must have app=frontend
          role: proxy             # AND role=proxy (both required!)
    ports:
    - protocol: TCP
      port: 7000                  # Only allow port 7000
```

**Key Points:**
1. **podSelector in spec**: Selects which pods this policy applies to (`app=api`)
2. **policyTypes**: Specifies this controls Ingress (incoming) traffic
3. **from + podSelector**: Defines source pods (must have BOTH labels)
4. **ports**: Restricts to TCP port 7000 only
5. **Default deny**: Any traffic not matching these rules is automatically denied

**Step 6: View effective policy**

```bash
# See detailed NetworkPolicy information
kubectl get networkpolicy allow-multi-pod-ingress -n isolated -o yaml

# View which pods are selected by the policy
kubectl get pods -n isolated -l app=api --show-labels
```

**Verification checklist:**
- ✅ NetworkPolicy named `allow-multi-pod-ingress` created
- ✅ Policy applied in namespace `isolated`
- ✅ Policy targets pods with label `app=api`
- ✅ Policy allows ingress from pods with BOTH `app=frontend` AND `role=proxy`
- ✅ Policy allows only TCP port 7000
- ✅ frontend-proxy-pod can access api-pod:7000
- ✅ frontend-only-pod CANNOT access api-pod:7000
- ✅ database-pod CANNOT access api-pod:7000
- ✅ Port 8080 is blocked on api-pod-alt

</details>

---

### 🎯 **Common Mistakes to Avoid**

<details><summary>View common pitfalls</summary>

**Mistake 1: Using separate podSelectors (OR logic instead of AND)**
```yaml
# WRONG - This creates OR logic (either label matches)
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
  - podSelector:
      matchLabels:
        role: proxy
```

**Correct - Single podSelector with multiple labels (AND logic)**
```yaml
# CORRECT - Both labels required
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
        role: proxy
```

**Mistake 2: Forgetting policyTypes**
```yaml
# WRONG - Without policyTypes, behavior may be unexpected
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from: ...
```

**Correct**
```yaml
# CORRECT - Explicitly declare policy type
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from: ...
```

**Mistake 3: Wrong indentation for ports**
```yaml
# WRONG - ports at wrong level
ingress:
- from:
  - podSelector: ...
  ports:
  - protocol: TCP
    port: 7000
```
This is actually CORRECT! The `ports` field at this level applies to ALL sources in the `from` list.

**Mistake 4: Not testing thoroughly**
Always test both positive (should work) and negative (should fail) cases!

</details>
