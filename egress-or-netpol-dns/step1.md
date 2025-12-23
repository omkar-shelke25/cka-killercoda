# 🔒 **CKA: Configure Egress NetworkPolicy with OR Logic**

📚 **Official Kubernetes Documentation**: 
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### 🏢 **Context**

You are the security engineer for a microservices platform. The application pods in the `restricted` namespace need controlled outbound access to backend services. For security compliance, you must implement a **default-deny egress policy** with explicit allowlisting.

The application needs to connect to either:
- A PostgreSQL database service (app=database) in the `data` namespace, OR
- A Redis cache service (role=cache) in the `cache` namespace

Both services listen on port 5432. Additionally, DNS must work for service discovery.

### ❓ **Problem Statement**

Create a new NetworkPolicy named `allow-egress-or-logic` in the existing namespace `restricted`.

The NetworkPolicy should allow outgoing (egress) traffic from Pods in namespace `restricted` only if **all** of the following conditions are met:

* Traffic is destined to Pods with label `app=database` in namespace `data`
* **OR** traffic is destined to Pods with label `role=cache` in namespace `cache`
* Traffic is directed to TCP port 5432
* DNS must be allowed, but only to `kube-dns` Pods in the `kube-system` namespace, and only on UDP/TCP port 53
* Pods must not be able to send traffic to any other Pods, namespaces, or external destinations
* Pods that do not send traffic on port 5432 must not be allowed egress access

**Requirements Summary:**
- NetworkPolicy name: `allow-egress-or-logic`
- Namespace: `restricted`
- Policy type: Egress
- Allowed destinations:
  - Database pods (`app=database` in `data` namespace) on port 5432, OR
  - Cache pods (`role=cache` in `cache` namespace) on port 5432
  - DNS pods (`k8s-app=kube-dns` in `kube-system` namespace) on port 53 UDP/TCP
- All other egress traffic: Denied

---

### 💡 **Critical Concepts**

<details><summary>🔍 Understanding Egress Policies</summary>

**Egress policies control OUTBOUND traffic from pods:**

```yaml
spec:
  policyTypes:
  - Egress              # Controls traffic leaving the pod
  egress:
  - to:                 # Where can pods send traffic?
    - namespaceSelector: ...
      podSelector: ...
    ports:
    - port: 5432
```

**Key differences from Ingress:**
- **Ingress**: Controls who can access YOUR pods (incoming)
- **Egress**: Controls what YOUR pods can access (outgoing)

**Default behavior:**
- Without NetworkPolicy: All egress allowed
- With Egress policy: Only explicitly allowed destinations permitted

</details>

<details><summary>🔍 Implementing OR Logic in NetworkPolicy</summary>

To allow traffic to **multiple destinations** (OR logic), use **separate items** in the `to` list:

```yaml
egress:
- to:
  - namespaceSelector:        # Destination 1
      matchLabels:
        name: data
    podSelector:
      matchLabels:
        app: database
  - namespaceSelector:        # OR Destination 2 (separate item)
      matchLabels:
        name: cache
    podSelector:
      matchLabels:
        role: cache
  ports:
  - protocol: TCP
    port: 5432
```

**Important:** Each item in the `to` list represents an OR condition. Traffic matching ANY of them is allowed.

</details>

<details><summary>🔍 DNS Allowlisting Pattern</summary>

For pods to resolve service names (e.g., `database.data.svc.cluster.local`), they need DNS access:

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53
```

**Why both UDP and TCP?**
- DNS primarily uses UDP port 53
- TCP port 53 is used for large responses or zone transfers
- Both should be allowed for reliable DNS resolution

</details>

<details><summary>🔍 Common Egress Policy Pitfalls</summary>

**Pitfall 1: Forgetting DNS**
```yaml
# ❌ Pods can't resolve service names!
egress:
- to:
  - namespaceSelector: ...
    podSelector: ...
  ports:
  - port: 5432
# Missing DNS rule!
```

**Pitfall 2: Wrong selector for kube-dns**
```yaml
# ❌ Wrong label
podSelector:
  matchLabels:
    app: kube-dns      # Should be k8s-app=kube-dns
```

**Pitfall 3: Using AND instead of OR**
```yaml
# ❌ This requires BOTH labels (impossible!)
to:
- namespaceSelector:
    matchLabels:
      name: data
  podSelector:
    matchLabels:
      app: database
      role: cache      # Can't have both labels!
```

**Pitfall 4: Missing namespace selector**
```yaml
# ❌ Only works within same namespace
to:
- podSelector:
    matchLabels:
      app: database
```

</details>

---

### 🧪 **Testing Your Solution**

After creating the NetworkPolicy, verify it works correctly:

<details><summary>View testing commands</summary>

**1. Test access to database (should SUCCEED):**
```bash
APP_POD=$(kubectl get pod -n restricted -l app=application -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 database.data.svc.cluster.local:5432
```

**2. Test access to cache (should SUCCEED):**
```bash
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 cache.cache.svc.cluster.local:5432
```

**3. Test access to other namespace (should FAIL):**
```bash
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 other-app.other.svc.cluster.local:80
```

**4. Test DNS resolution (should SUCCEED):**
```bash
kubectl exec -n restricted $APP_POD -- nslookup kubernetes.default
```

**5. View NetworkPolicy:**
```bash
kubectl get networkpolicy -n restricted
kubectl describe networkpolicy allow-egress-or-logic -n restricted
```

</details>

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Understand the requirements**

We need to create an egress policy that allows:
1. ✅ Traffic to `app=database` pods in `data` namespace on port 5432
2. ✅ OR traffic to `role=cache` pods in `cache` namespace on port 5432
3. ✅ DNS queries to kube-dns on port 53 (UDP and TCP)
4. ❌ All other egress traffic is denied

**Step 2: Check namespace and pod labels**

```bash
# Verify namespace labels
kubectl get namespace data cache kube-system --show-labels

# Verify pod labels
kubectl get pods -n data --show-labels
kubectl get pods -n cache --show-labels
kubectl get pods -n kube-system -l k8s-app=kube-dns --show-labels
```

**Step 3: Create the NetworkPolicy**

```bash
kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-or-logic
  namespace: restricted
spec:
  podSelector: {}                    # Apply to all pods in namespace
  policyTypes:
  - Egress                           # This is an egress policy
  egress:
  - to:                              # Rule 1: Database OR Cache
    - namespaceSelector:             # Destination 1: Database
        matchLabels:
          name: data
      podSelector:
        matchLabels:
          app: database
    - namespaceSelector:             # OR Destination 2: Cache
        matchLabels:
          name: cache
      podSelector:
        matchLabels:
          role: cache
    ports:
    - protocol: TCP
      port: 5432
  - to:                              # Rule 2: DNS
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

**Alternative: Using YAML file**

```bash
cat > networkpolicy.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-or-logic
  namespace: restricted
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: data
      podSelector:
        matchLabels:
          app: database
    - namespaceSelector:
        matchLabels:
          name: cache
      podSelector:
        matchLabels:
          role: cache
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

kubectl apply -f networkpolicy.yaml
```

**Step 4: Verify the policy was created**

```bash
kubectl get networkpolicy -n restricted
kubectl describe networkpolicy allow-egress-or-logic -n restricted
```

**Step 5: Understanding the configuration**

Let's break down the YAML:

```yaml
spec:
  podSelector: {}                    # Applies to ALL pods in restricted namespace
  policyTypes:
  - Egress                           # Controls outbound traffic
  
  egress:
  # First egress rule: Database OR Cache on port 5432
  - to:
    - namespaceSelector:             # ← Destination option 1
        matchLabels:
          name: data
      podSelector:
        matchLabels:
          app: database
    - namespaceSelector:             # ← Destination option 2 (separate item = OR)
        matchLabels:
          name: cache
      podSelector:
        matchLabels:
          role: cache
    ports:
    - protocol: TCP
      port: 5432                     # Both destinations use same port
  
  # Second egress rule: DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

**Key Points:**
1. **podSelector: {}** - Applies to all pods in the restricted namespace
2. **Two egress rules** - One for database/cache, one for DNS
3. **OR logic** - Multiple items in `to` list create OR conditions
4. **Both protocols for DNS** - UDP and TCP on port 53

**Step 6: Test the NetworkPolicy**

Get a pod to test from:
```bash
APP_POD=$(kubectl get pod -n restricted -l app=application -o jsonpath='{.items[0].metadata.name}')
echo "Testing from pod: $APP_POD"
```

**Test 1: Access to database (should SUCCEED)**
```bash
echo "=== Test 1: Access to database (should SUCCEED) ==="
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 database.data.svc.cluster.local:5432 | grep -o "<title>.*</title>"
```

**Test 2: Access to cache (should SUCCEED)**
```bash
echo "=== Test 2: Access to cache (should SUCCEED) ==="
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 cache.cache.svc.cluster.local:5432 | grep -o "<title>.*</title>"
```

**Test 3: Access to other namespace (should FAIL)**
```bash
echo "=== Test 3: Access to other namespace (should FAIL) ==="
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 other-app.other.svc.cluster.local:80 && echo "❌ ALLOWED" || echo "✅ BLOCKED (correct)"
```

**Test 4: DNS resolution (should SUCCEED)**
```bash
echo "=== Test 4: DNS resolution (should SUCCEED) ==="
kubectl exec -n restricted $APP_POD -- nslookup kubernetes.default
```

**Test 5: External access (should FAIL if no internet, or blocked)**
```bash
echo "=== Test 5: External access (should FAIL) ==="
kubectl exec -n restricted $APP_POD -- curl -s --max-time 5 google.com && echo "❌ ALLOWED" || echo "✅ BLOCKED (correct)"
```

**Step 7: Verify the egress rules**

```bash
# View full policy
kubectl get networkpolicy allow-egress-or-logic -n restricted -o yaml

# Check egress destinations
kubectl get networkpolicy allow-egress-or-logic -n restricted -o jsonpath='{.spec.egress}' | jq

# Verify it's an egress policy
kubectl get networkpolicy allow-egress-or-logic -n restricted -o jsonpath='{.spec.policyTypes}'
```

**Step 8: Understanding OR logic in this policy**

The policy allows egress to:
```
(app=database in data namespace) 
    OR 
(role=cache in cache namespace)
```

Both on port 5432, PLUS DNS on port 53.

This is achieved by having TWO separate items in the first `to` list:
```yaml
to:
- item1: database destination    # ← Option 1
- item2: cache destination        # ← Option 2 (OR)
```

**Verification checklist:**
- ✅ NetworkPolicy named `allow-egress-or-logic` created
- ✅ Applied in `restricted` namespace
- ✅ Policy type is Egress
- ✅ Applies to all pods in namespace (podSelector: {})
- ✅ Allows traffic to database pods in data namespace
- ✅ Allows traffic to cache pods in cache namespace
- ✅ Both destinations use port 5432
- ✅ Allows DNS to kube-dns on port 53 (UDP and TCP)
- ✅ Blocks all other egress traffic
- ✅ OR logic implemented correctly

</details>

---

### 🎯 **Key Takeaways**

<details><summary>View critical points</summary>

**1. Egress policies control OUTBOUND traffic:**
```yaml
policyTypes:
- Egress              # Outgoing from pods
```

**2. OR logic uses separate to items:**
```yaml
to:
- destination1        # Option 1
- destination2        # OR Option 2
```

**3. Always include DNS for service discovery:**
```yaml
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53
```

**4. podSelector: {} applies to all pods:**
```yaml
podSelector: {}       # All pods in namespace
```

**5. Each egress rule is independent:**
```yaml
egress:
- rule1: database or cache
- rule2: DNS
```

</details>

---

### 📝 **Additional Commands**

<details><summary>Useful testing and debugging commands</summary>

```bash
# List all network policies
kubectl get networkpolicy -A

# Check if DNS works
kubectl exec -n restricted $APP_POD -- nslookup database.data.svc.cluster.local

# Check if service exists
kubectl get svc -n data
kubectl get svc -n cache

# View pod IPs
kubectl get pods -n data -o wide
kubectl get pods -n cache -o wide

# Test with verbose curl
kubectl exec -n restricted $APP_POD -- curl -v database.data:5432

# Check kube-dns pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# View egress rules in JSON
kubectl get networkpolicy allow-egress-or-logic -n restricted -o json | jq '.spec.egress'
```

</details>
