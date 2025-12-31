# 🔒 **CKA: Implement Network Security - NetworkPolicy**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

### 🏢 **Context**

A security incident occurred where an intruder gained access to the entire cluster through a compromised backend Pod. The security team has identified that backend Pods had unrestricted network access to all resources in the `project-snake` namespace.

To prevent future incidents, you must implement strict network segmentation using NetworkPolicy.

---

### 🎯 **Your Task**

Create a NetworkPolicy named `np-backend` in the `project-snake` namespace with the following requirements:

**Network Access Rules:**
* Backend Pods (labeled `app=backend`) should **ONLY** be able to:
  * Connect to `db1` Pods (labeled `app=db1`) on port `1111`
  * Connect to `db2` Pods (labeled `app=db2`) on port `2222`
* All other egress traffic from backend Pods should be blocked
* Connections to other Pods like `vault` on port `3333` should **NOT** work

**Requirements:**
* NetworkPolicy name: `np-backend`
* Namespace: `project-snake`
* Use Pod label `app` for selectors
* Apply egress rules to restrict outbound traffic
* Use Pod IP communication only (no DNS required)

**Testing:**
All Pods run plain Nginx, allowing connectivity tests using Pod IPs:
```bash
# This should work (db1 on port 1111)
kubectl -n project-snake exec backend-0 -- curl <db1-pod-ip>:1111

# This should work (db2 on port 2222)
kubectl -n project-snake exec backend-0 -- curl <db2-pod-ip>:2222

# This should NOT work (vault on port 3333)
kubectl -n project-snake exec backend-0 -- curl <vault-pod-ip>:3333
```

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Examine the current setup**

Check existing Pods and their labels:
```bash
kubectl get pods -n project-snake --show-labels
```

Get Pod IPs for testing:
```bash
kubectl get pods -n project-snake -o wide
```

**Step 2: Test current connectivity (before NetworkPolicy)**

```bash
# Get Pod IPs
DB1_IP=$(kubectl get pod -n project-snake -l app=db1 -o jsonpath='{.items[0].status.podIP}')
DB2_IP=$(kubectl get pod -n project-snake -l app=db2 -o jsonpath='{.items[0].status.podIP}')
VAULT_IP=$(kubectl get pod -n project-snake -l app=vault -o jsonpath='{.items[0].status.podIP}')

# Test from backend Pod (all should work initially)
kubectl -n project-snake exec backend-0 -- curl -m 2 $DB1_IP:1111
kubectl -n project-snake exec backend-0 -- curl -m 2 $DB2_IP:2222
kubectl -n project-snake exec backend-0 -- curl -m 2 $VAULT_IP:3333
```

**Step 3: Create the NetworkPolicy**

Create the NetworkPolicy file:
```bash
cat > np-backend.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-backend
  namespace: project-snake
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db1
    ports:
    - protocol: TCP
      port: 1111
  - to:
    - podSelector:
        matchLabels:
          app: db2
    ports:
    - protocol: TCP
      port: 2222
EOF
```

**Important Notes:**
* `podSelector` targets Pods with label `app=backend`
* `policyTypes: [Egress]` restricts outbound traffic
* First egress rule allows backend → db1 on port 1111
* Second egress rule allows backend → db2 on port 2222
* No rule for vault, so connections to vault will be blocked
* No DNS rule needed since we're using Pod IPs directly

**Step 4: Apply the NetworkPolicy**

```bash
kubectl apply -f np-backend.yaml
```

Verify it was created:
```bash
kubectl get networkpolicy -n project-snake
kubectl describe networkpolicy np-backend -n project-snake
```

**Step 5: Test connectivity after NetworkPolicy**

```bash
# These should work
kubectl -n project-snake exec backend-0 -- curl -m 2 $DB1_IP:1111
kubectl -n project-snake exec backend-0 -- curl -m 2 $DB2_IP:2222

# This should timeout/fail
kubectl -n project-snake exec backend-0 -- curl -m 2 $VAULT_IP:3333
```

Expected results:
* ✅ Connection to db1:1111 succeeds
* ✅ Connection to db2:2222 succeeds
* ❌ Connection to vault:3333 times out (blocked by policy)

**Step 6: Verify the security improvement**

```bash
# Show all NetworkPolicies
kubectl get networkpolicies -n project-snake

# Describe the policy to see rules
kubectl describe networkpolicy np-backend -n project-snake
```

The output should show:
* Policy applies to Pods with `app=backend`
* Egress allowed only to db1:1111 and db2:2222
* All other egress traffic denied

</details>

---
