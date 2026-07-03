# **CKA: Configure NetworkPolicy with Multi-Label Selection**

📚 **Official Kubernetes Documentation**:
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### **Context**

You are the security engineer for a microservices platform running in Kubernetes. The security team has identified that the API service in the `isolated` namespace requires strict access controls.

### **Problem Statement**

Create a new NetworkPolicy named `allow-multi-pod-ingress` in the existing namespace `isolated`.

The NetworkPolicy must select Pods with label `app=api`, and allow incoming traffic to those Pods only if **ALL** of the following conditions are met:

* Traffic comes from a Pod that carries **both** labels together: `app=frontend` **and** `role=proxy`. A Pod with only one of the two labels does not count.
* Traffic is directed to **TCP port 7000**. Traffic to any other port on an `app=api` Pod (for example port 8080) must be denied.
* Traffic from any Pod that doesn't carry both required labels — such as `app=frontend` alone, or `app=database` — must be denied.

> ℹ️ **Note on scope:** A NetworkPolicy's `podSelector` field decides which Pods the policy *applies to* — it isn't a namespace-wide lockdown. This policy only governs traffic to Pods labeled `app=api`. Pods without that label sit outside this policy's scope, so this task only concerns access **to** `app=api` Pods, not general access between every other Pod pair in the namespace. See the [Network Policies docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/) for how per-Pod isolation works.

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Understand the requirements**

We need to create a NetworkPolicy that:
- Selects target pods with label `app=api`
- Allows ingress traffic ONLY from pods with BOTH labels: `app=frontend` AND `role=proxy` (a single `podSelector` with both labels — that's AND logic, not two separate selectors)
- Allows traffic ONLY to port 7000 TCP
- Denies all other ingress traffic to `app=api` pods (implicit default-deny once a policy selects a pod)

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
          role: proxy             # AND role=proxy (both required, single selector = AND logic)
    ports:
    - protocol: TCP
      port: 7000                  # Only allow port 7000
```

</details>
