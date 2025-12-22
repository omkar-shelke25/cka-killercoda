## 🔒 CKA Exam Question - Configure NetworkPolicy


### 📖 Problem Statement

Create a new NetworkPolicy named `allow-port-from-namespace` in the existing namespace `fubar`.

The NetworkPolicy should allow incoming traffic to Pods in namespace `fubar` only if all of the following conditions are met:
- Traffic originates from Pods in the namespace `internal`
- Traffic is directed to TCP port `9000`
- Pods that do not listen on port `9000` must not be accessible
- Pods from namespaces other than `internal` must not be allowed access

---

### ✅ Solution

<details><summary>Click to view complete solution</summary>

#### Create NetworkPolicy

```bash
cat > allow-port-from-namespace.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-from-namespace
  namespace: fubar
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: internal
    ports:
    - protocol: TCP
      port: 9000
EOF

# Apply the NetworkPolicy
kubectl apply -f allow-port-from-namespace.yaml
```

#### Verify NetworkPolicy

```bash
# Check NetworkPolicy exists
kubectl get networkpolicy -n fubar

# View NetworkPolicy details
kubectl describe networkpolicy allow-port-from-namespace -n fubar

# View YAML
kubectl get networkpolicy allow-port-from-namespace -n fubar -o yaml
```

#### Test Access Control

```bash
# Test 1: internal → app-9000:9000 (Should SUCCEED)
kubectl exec -n internal internal-client -- wget -qO- --timeout=2 app-9000-service.fubar.svc.cluster.local:9000

# Test 2: internal → app-8080:8080 (Should FAIL - wrong port)
kubectl exec -n internal internal-client -- wget -qO- --timeout=2 app-8080-service.fubar.svc.cluster.local:8080

# Test 3: external → app-9000:9000 (Should FAIL - wrong namespace)
kubectl exec -n external external-client -- wget -qO- --timeout=2 app-9000-service.fubar.svc.cluster.local:9000

# Test 4: external → app-8080:8080 (Should FAIL - both wrong)
kubectl exec -n external external-client -- wget -qO- --timeout=2 app-8080-service.fubar.svc.cluster.local:8080
```

#### Complete Verification

```bash
# Check all resources
kubectl get networkpolicy,pods,svc -n fubar

# Verify namespace labels
kubectl get namespace internal -o yaml | grep labels -A 5

# View all NetworkPolicies
kubectl get networkpolicy -A
```

</details>
