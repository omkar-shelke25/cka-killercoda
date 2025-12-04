## 🎴 The Migration Game - Survive or Die

---

### 📖 Game Scenario

Welcome to the **Borderland**. You've entered **The Migration Game** - a deadly challenge where outdated technology means death.

Your web application currently uses an **Ingress resource** to route traffic. 

The Game Master has declared that Ingress is obsolete. You must migrate to the new **Gateway API** before time runs out.

**Failure means GAME OVER** 💀

---

### 🎯 Your Tasks

#### Task 1: Create Gateway Resource

Create a **Gateway** named `web-gateway` in the `borderland` namespace.

**Requirements:**

| Element | Specification |
|---------|--------------|
| Name | `web-gateway` |
| Namespace | `borderland` |
| GatewayClassName | `nginx` |
| Listener Protocol | `HTTPS` (TLS termination) |
| Listener Port | `443` |
| Hostname | `gateway.web.k8s.local` |
| TLS Mode | `Terminate` |
| TLS Secret | `web-tls` (same namespace) |

**Save to**: `/root/web-gateway.yaml`

---

#### Task 2: Create HTTPRoute Resource

Create an **HTTPRoute** named `web-route` in the `borderland` namespace.

**Requirements:**

| Element | Specification |
|---------|--------------|
| Name | `web-route` |
| Namespace | `borderland` |
| Parent Gateway | `web-gateway` |
| Hostname | `gateway.web.k8s.local` |
| Route 1 | `/games` → `games-service` port 80 |
| Route 2 | `/players` → `players-service` port 80 |
| Path Type | `PathPrefix` |

**Save to**: `/root/web-route.yaml`

---

### ✅ Solution (Try yourself first!)

<details>
<summary>Click to reveal complete solution</summary>

#### Task 1: Create Gateway

```bash
cat > /root/web-gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: borderland
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: gateway.web.k8s.local
    tls:
      mode: Terminate
      certificateRefs:
      - name: web-tls
EOF

# Apply Gateway
kubectl apply -f /root/web-gateway.yaml
```

#### Task 2: Create HTTPRoute

```bash
cat > /root/web-route.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: borderland
spec:
  parentRefs:
  - name: web-gateway
  hostnames:
  - "gateway.web.k8s.local"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/games"
    backendRefs:
    - name: games-service
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: "/players"
    backendRefs:
    - name: players-service
      port: 80
EOF

# Apply HTTPRoute
kubectl apply -f /root/web-route.yaml
```

#### Verify and Test

```bash
# Check Gateway
kubectl get gateway web-gateway -n borderland
kubectl describe gateway web-gateway -n borderland

# Check HTTPRoute
kubectl get httproute web-route -n borderland
kubectl describe httproute web-route -n borderland

# Get Gateway IP
GATEWAY_IP=$(kubectl get gateway web-gateway -n borderland -o jsonpath='{.status.addresses[0].value}')
echo $GATEWAY_IP

# Configure DNS
echo "${GATEWAY_IP} gateway.web.k8s.local" | sudo tee -a /etc/hosts

# Test endpoints
curl -k https://gateway.web.k8s.local/games | jq '.service'
curl -k https://gateway.web.k8s.local/players | jq '.service'
```

</details>
