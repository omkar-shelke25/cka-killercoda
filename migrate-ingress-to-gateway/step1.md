## 🎴 CKA: The Migration Game - Survive or Die

### 📚 Official Documentation
 - [Gateway K8S](https://kubernetes.io/docs/concepts/services-networking/gateway/)
 - [Gateway API - HTTPRoute](https://gateway-api.sigs.k8s.io/guides/http-routing/)
 - [Gateway API - Migration Guide](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
 
---

### 📖 Game Scenario

Welcome to the **Borderland**. You've entered **The Migration Game** - a deadly challenge where outdated technology means death.

Your web application currently uses an **Ingress resource** to route traffic. 

The Game Master has declared that Ingress is obsolete. You must migrate to the new **Gateway API** before time runs out.

**Failure means GAME OVER** 💀

---

### 🎯 Your Tasks

An existing Ingress configuration is already present in the file:

```
/borderland-ingress/ingress.yaml
```

Review this Ingress and migrate it to the Gateway API.

#### Task 1: Create Gateway Resource

Create a Gateway named **`web-gateway`** in the **`borderland`** namespace using the **`nginx`** GatewayClass.

The Gateway must listen on HTTPS port **`443`**, terminate TLS using the same secret referenced by the Ingress, and serve the host **`gateway.web.k8s.local`**.

TLS Secret`web-tls` has been present in same namespace.

Save the Gateway manifest to:

```
/root/web-gateway.yaml
```

---

#### Task 2: Create HTTPRoute Resource
Then create an HTTPRoute in the **borderland** namespace named **web-route** that reproduces the routing behavior of the Ingress.

The route should match the same host and forward requests from **`/games`** to **`games-service`** on port **`80`** and from **`/players`** to **`players-service`** on port **`80`**, using PathPrefix matching.

Save the HTTPRoute manifest to:

```
/root/web-route.yaml
```

#### Task 3: 

Ensure that only the Gateway IP is present in /etc/hosts, and remove any entries related to the Ingress controller

Delete the existing Ingress after the migration to the Gateway has been successfully completed.

```
# Test endpoints
curl -k https://gateway.web.k8s.local/games | jq 
curl -k https://gateway.web.k8s.local/players | jq 
```

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
curl -k https://gateway.web.k8s.local/games | jq 
curl -k https://gateway.web.k8s.local/players | jq 
```

</details>
