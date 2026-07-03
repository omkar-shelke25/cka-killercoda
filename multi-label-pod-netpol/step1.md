# **CKA: Configure NetworkPolicy with Multi-Label Selection**

📚 **Official Kubernetes Documentation**:
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [NetworkPolicy API Reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#networkpolicy-v1-networking-k8s-io)

### **Context**

You are the security engineer for a microservices platform running in Kubernetes. The security team has identified that the API service in the `isolated` namespace requires strict access controls.

### **Problem Statement**

Create a new NetworkPolicy named `allow-multi-pod-ingress` in the existing namespace `isolated`.

The NetworkPolicy must select Pods with label `app=api`, and allow incoming traffic **to those Pods** only if **ALL** of the following conditions are met:

* Traffic comes from a Pod that carries **both** labels together: `app=frontend` **and** `role=proxy`. A Pod with only one of the two labels does not count.
* Traffic is directed to **TCP port 7000**. Traffic to any other port on an `app=api` Pod (for example port 8080) must be denied.
* Traffic from any Pod that doesn't carry both required labels — such as `app=frontend` alone, or `app=database` — must be denied **ingress to the `app=api` Pods**.

> ℹ️ **Note on scope:** A NetworkPolicy's `podSelector` field decides which Pods the policy *applies to* — it isn't a namespace-wide lockdown. This policy only governs ingress **to** Pods labeled `app=api`. Pods without that label sit outside this policy's scope entirely: they are neither protected nor restricted by it, and traffic between *other* pod pairs in the namespace (e.g. `frontend` → `database`) is unaffected. This exercise is only about who may reach `app=api` Pods, not about locking down the whole namespace. See the [Network Policies docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/) for how per-Pod isolation works — isolation is applied per-Pod, based on which Pods a policy's `podSelector` matches, not applied namespace-wide by default.

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Understand the requirements**

We need to create a NetworkPolicy that:
- Selects target pods with label `app=api`
- Allows ingress traffic ONLY from pods with BOTH labels: `app=frontend` AND `role=proxy` (a single `podSelector` with both labels — that's AND logic, not two separate selectors)
- Allows traffic ONLY to port 7000 TCP
- Denies all other ingress traffic to `app=api` pods (implicit default-deny once a policy selects a pod)

This is scoped to ingress on `app=api` pods only. It does not, and is not meant to, restrict traffic between other pods in the namespace — see the scope note above.

**Step 2: Create the NetworkPolicy**

Prefer `kubectl apply`, since it's idempotent and won't error out if you re-run it after an earlier attempt (`kubectl create` will fail with "AlreadyExists" if the object is already there):

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

**Step 4: Set up test pods**

The tests below assume these pods already exist in `isolated`. If you're building the exercise from scratch, create them first — in particular `api-pod-alt`, which earlier versions of this exercise referenced in Test 4 without ever defining it:

```bash
kubectl run api-pod -n isolated --image=hashicorp/http-echo --labels=app=api \
  --port=7000 -- -listen=:7000 -text="api-pod:7000 ok"

kubectl run api-pod-alt -n isolated --image=hashicorp/http-echo --labels=app=api \
  --port=8080 -- -listen=:8080 -text="api-pod-alt:8080 ok"

kubectl run frontend-proxy-pod -n isolated --image=curlimages/curl \
  --labels=app=frontend,role=proxy -- sleep 3600

kubectl run frontend-only-pod -n isolated --image=curlimages/curl \
  --labels=app=frontend -- sleep 3600

kubectl run database-pod -n isolated --image=curlimages/curl \
  --labels=app=database -- sleep 3600

kubectl wait --for=condition=Ready pod --all -n isolated --timeout=60s
```

> Also expose `api-pod` and `api-pod-alt` as Services (or curl the Pod IPs directly) so the DNS names used in the tests below actually resolve. If you'd rather curl by IP, swap in `$(kubectl get pod api-pod -n isolated -o jsonpath='{.status.podIP}')` etc.

**Step 5: Test the NetworkPolicy**

Each test now checks curl's own exit code instead of grepping for HTML — the exit code tells you definitively whether the connection was made or blocked, regardless of what's actually listening on the port.

**Test 1: From frontend-proxy-pod (should work — has both labels)**
```bash
echo "Test 1: frontend-proxy-pod to api-pod:7000 (should SUCCEED)"
kubectl exec -n isolated frontend-proxy-pod -- curl -s --max-time 3 -o /dev/null -w "%{http_code}\n" api-pod:7000 \
  && echo "ALLOWED ✓" || echo "BLOCKED (unexpected)"
```

**Test 2: From frontend-only-pod (should fail — missing role=proxy)**
```bash
echo "Test 2: frontend-only-pod to api-pod:7000 (should FAIL)"
kubectl exec -n isolated frontend-only-pod -- curl -s --max-time 3 -o /dev/null -w "%{http_code}\n" api-pod:7000 \
  && echo "ALLOWED (unexpected)" || echo "BLOCKED ✓"
```

**Test 3: From database-pod (should fail — wrong labels)**
```bash
echo "Test 3: database-pod to api-pod:7000 (should FAIL)"
kubectl exec -n isolated database-pod -- curl -s --max-time 3 -o /dev/null -w "%{http_code}\n" api-pod:7000 \
  && echo "ALLOWED (unexpected)" || echo "BLOCKED ✓"
```

**Test 4: To port 8080 on api-pod-alt (should fail — wrong port)**
```bash
echo "Test 4: frontend-proxy-pod to api-pod-alt:8080 (should FAIL)"
kubectl exec -n isolated frontend-proxy-pod -- curl -s --max-time 3 -o /dev/null -w "%{http_code}\n" api-pod-alt:8080 \
  && echo "ALLOWED (unexpected)" || echo "BLOCKED ✓"
```

> If every test reports "ALLOWED" — including the ones that should be blocked — stop and re-check the CNI prerequisite above before assuming the YAML is wrong.

**Step 6: Understanding the configuration**

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

**Out of scope, by design:** This policy does not, and should not, prevent traffic between pods that aren't labeled `app=api` (e.g. `frontend` → `database`). If a future requirement needs that, it's a separate NetworkPolicy selecting those other pods — bolting it onto this one via a `NotIn` match expression would silently change what this policy protects and likely break legitimate traffic that was never part of this exercise.

</details>
