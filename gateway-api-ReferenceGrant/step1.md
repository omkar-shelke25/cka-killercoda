## 🔬 CKA: Fix Cross-Namespace Access with ReferenceGrant

### Official Documentation
- [Gateway API - ReferenceGrant](https://gateway-api.sigs.k8s.io/api-types/referencegrant/)
- [Gateway API Security Model](https://gateway-api.sigs.k8s.io/concepts/security-model/)



### 📖 Scenario

The **Kanto Research Cloud Platform** runs workloads across multiple namespaces to isolate teams studying different Pokémon types.

The **Pokédex Frontend Team** reported that their HTTPRoute cannot reach a backend service in another namespace.

**Gateway Controller Error:**
```
❌ Cross-namespace reference denied: missing ReferenceGrant
```

> Please wait 1 minute for `MetalLoadBalancer` to set up the gateway.
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

Create a **ReferenceGrant** in the **`pokedex-core`** namespace. This ReferenceGrant must allow a cross-namespace reference **from an HTTPRoute** in the **`pokedex-ui`** namespace **to a Service** in the **`pokedex-core`** namespace.

In doing so, ensure the following conditions are met:

* It must authorize only the **`HTTPRoute`** kind from the **`gateway.networking.k8s.io`** API group.
* It must allow the reference only from the **`pokedex-ui`** namespace.
* It must permit access **only to the `evolution-engine` Service**, and no other Service.
* It must not authorize any additional resource types or namespaces beyond these requirements.


#### 3. File Location

Save the complete manifest to:
```bash
/root/poke-refgrant.yaml
```

> curl http://pokedex.kanto.lab/api/evolution | jq


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

