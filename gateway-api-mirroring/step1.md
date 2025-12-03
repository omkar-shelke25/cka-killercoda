## 🎬 Configure Gateway API Traffic Mirroring

📚 **Official Kubernetes Documentation**: 
- [Gateway API - HTTPRoute](https://gateway-api.sigs.k8s.io/guides/http-routing/)
- [Gateway API - HTTPRoute Filters](https://gateway-api.sigs.k8s.io/guides/http-request-mirroring/)
- [NGINX Gateway Fabric Documentation](https://docs.nginx.com/nginx-gateway-fabric/)


Your anime streaming platform has two API versions deployed in the `prod` namespace:
- `api-v1` - Stable production API serving anime recommendations
- `api-v2` - New API with ML-powered personalization (testing)

An existing Gateway `anime-app-gateway` is already configured in the `anime-gtw` namespace.

---

### 🎯 Your Task

Create an **HTTPRoute** named `anime-api-httproute` in the `prod` namespace that implements traffic mirroring.

#### Requirements:

1. **Name**: `anime-api-httproute`
2. **Namespace**: `prod`
3. **Attach to Gateway**: `anime-app-gateway` in namespace `anime-gtw`
4. **Hostname**: `anime.streaming.io` (DNS already set in /etc/hosts)
5. **Primary Backend**: `api-v1` (port 80) - Users receive responses from here
6. **Mirror Target**: `api-v2` (port 80) - Receives mirrored traffic
7. **Path**: `/` (PathPrefix)
8. Save your manifest to: `/root/api-route.yaml`

> Check the logs of the deployment; both deployments need to receive traffic.

> curl -s http://anime.streaming.io/ | jq
---

### 📝 Traffic Mirroring Concept

```
User Request → Gateway → HTTPRoute
                            ↓
                    ┌───────┴───────┐
                    ↓               ↓
              [api-v1]         [api-v2]
              (primary)        (mirror)
                    ↓               ↓
            Response sent    Response discarded
            to user          (testing only)
```

### ✅ Solution (Try it yourself first!)

<details><summary>Click to view complete solution</summary>

#### Create the HTTPRoute with Traffic Mirroring

```bash
cat > /root/api-route.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: anime-api-httproute
  namespace: prod
spec:
  parentRefs:
  - name: anime-app-gateway
    namespace: anime-gtw
  hostnames:
  - "anime.streaming.io"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/"
    backendRefs:
    - name: api-v1
      port: 80
    filters:
    - type: RequestMirror
      requestMirror:
        backendRef:
          name: api-v2
          port: 80
EOF

# Apply the configuration
kubectl apply -f /root/api-route.yaml
```

#### Verify HTTPRoute
```bash
# Check HTTPRoute status
kubectl get httproute -n prod

# View detailed information
kubectl describe httproute anime-api-httproute -n prod

# Check Gateway status
kubectl get gateway anime-app-gateway -n anime-gtw
```

#### Test the Configuration
```bash
# Check both API logs to verify mirroring
echo -e "\nChecking api-v1 logs (handles all requests):"
kubectl logs --tail=5 deployment/api-v1 -n prod

echo -e "\nChecking api-v2 logs (receives ~10% mirrored):"
kubectl logs --tail=5 deployment/api-v2 -n prod
```

#### View API Responses
```bash
# See full api-v1 response
echo "API v1 Response (what users see):"
curl -s http://anime.streaming.io/ | jq

```

</details>

