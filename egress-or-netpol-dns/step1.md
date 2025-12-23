# 🔒 **CKA: Configure Egress NetworkPolicy with OR Logic**

📚 **Official Kubernetes Documentation**: 
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### 🏢 **Context**

You are the security engineer for a microservices platform. The application pods in the `restricted` namespace need controlled outbound access to backend services.

### ❓ **Problem Statement**

Create a new NetworkPolicy named `allow-egress-or-logic` in the existing namespace `restricted`.

The NetworkPolicy should allow outgoing (egress) traffic from Pods in namespace `restricted` only if **all** of the following conditions are met:

* Traffic is destined to Pods with label `app=database` in namespace `data` **OR** traffic is destined to Pods with label `role=cache` in namespace `cache`
* Traffic is directed to TCP port 5432
* DNS must be allowed, but only to `kube-dns` Pods in the `kube-system` namespace, and only on UDP/TCP port 53
* Pods must not be able to send traffic to any other Pods, namespaces, or external destinations
* Pods that do not send traffic on port 5432 must not be allowed egress access


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

**Test 4: External access (should FAIL if no internet, or blocked)**
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

