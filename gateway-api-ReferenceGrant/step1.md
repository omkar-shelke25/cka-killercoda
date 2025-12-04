## 🔬 CKA: Fix Cross-Namespace Access with ReferenceGrant

### 📖 Scenario

The **Kanto Research Cloud Platform** runs workloads across multiple namespaces to isolate teams studying different Pokémon types.

The **Pokédex Frontend Team** reported that their HTTPRoute cannot reach a backend service in another namespace.

**Gateway Controller Error:**
```
❌ Cross-namespace reference denied: missing ReferenceGrant
```

---

### 🧪 Current State

**Namespaces:**
- `pokedex-ui` → hosts the public HTTPRoute used by trainers
- `pokedex-core` → hosts evolution, stats, and move calculation services

**Existing Resources:**
- Gateway: `kanto-gateway` (namespace: `gateway-system`) ✅
- HTTPRoute: `trainer-api-route` (namespace: `pokedex-ui`) ✅
- Service: `evolution-engine` (namespace: `pokedex-core`) ✅

**The Problem:**
The HTTPRoute in `pokedex-ui` is trying to reference Service `evolution-engine` in namespace `pokedex-core`, but this cross-namespace reference is **blocked** for security reasons.


---

### 🎯 Your Task

Create a **ReferenceGrant** in the `pokedex-core` namespace that satisfies ALL of the following requirements:

#### 1. Allow Cross-Namespace Reference

**From** (Source):
```yaml
group: gateway.networking.k8s.io
kind: HTTPRoute
namespace: pokedex-ui
```

**To** (Target):
```yaml
group: ""              # Core API group (for Services)
kind: Service
# No namespace specified here - ReferenceGrant is created in target namespace
```

#### 2. Security Constraints

- ✅ Must allow ONLY `evolution-engine` Service (no wildcarding)
- ✅ Must allow ONLY HTTPRoute kind (no other resource types)
- ✅ Must allow ONLY from `pokedex-ui` namespace (no other namespaces)
- ❌ Do NOT authorize other resources or namespaces

#### 3. File Location

Save the complete manifest to:
```bash
/root/poke-refgrant.yaml
```



### ✅ Solution (Try yourself first!)

<details>
<summary>Click to reveal complete solution</summary>

#### Create the ReferenceGrant

```bash
cat > /root/poke-refgrant.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-ui-to-evolution
  namespace: pokedex-core
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: pokedex-ui
  to:
  - group: ""
    kind: Service
    name: evolution-engine
EOF
```

#### Apply the Configuration

```bash
# Apply ReferenceGrant
kubectl apply -f /root/poke-refgrant.yaml

# Verify it was created
kubectl get referencegrant -n pokedex-core
```

#### Verify HTTPRoute Now Works

```bash
# Check HTTPRoute status (should show Accepted: True)
kubectl describe httproute trainer-api-route -n pokedex-ui

# Check Gateway
kubectl get gateway kanto-gateway -n gateway-system

# Verify Service exists
kubectl get svc evolution-engine -n pokedex-core
```

#### Test the API

```bash
# Configure DNS
echo "192.168.1.240 pokedex.kanto.lab" | sudo tee -a /etc/hosts

# Test endpoint
curl http://pokedex.kanto.lab/api/evolution | jq

# Should return Pokémon evolution data
```

#### Monitor Logs

```bash
# Watch service logs to see requests
kubectl logs -f deployment/evolution-engine -n pokedex-core
```

</details>

