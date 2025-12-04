## 🔬 CKA: Canary Deployment with Gateway API

### 📚 Official Documentation
- [Gateway API - Traffic Splitting](https://gateway-api.sigs.k8s.io/guides/traffic-splitting/)
- [HTTPRoute Reference](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPRoute)


### 📖 Scenario

Hawkins Lab operates a Kubernetes cluster powering the **Stranger Things Streaming API**, which serves episode and character recommendations across Hawkins.

A new build called **"Upside Down Mode"** must be rolled out safely using a canary deployment through the Gateway API.

---

### 🧪 Current State

In the `hawkins` namespace, two backend services are running:

- **stv-v1** → Stable version (trusted by Eleven) ✅
- **stv-v2** → Experimental "Upside Down" version (tested by Dustin) 🧪

A Gateway named **stranger-gw** exists in namespace **str-gtw**.

Hawkins engineers want to gradually route traffic to the new version using weighted traffic splitting.

---

### 🎯 Your Task

Create an **HTTPRoute** named `stranger-canary-route` in the `hawkins` namespace that satisfies ALL of the following requirements:

#### 1. Gateway Attachment
```yaml
parentRefs:
- name: stranger-gw
  namespace: str-gtw
```

#### 2. Hostname Matching
- Host: `api.stranger.things` ( SNA already Configured in /etc/hosts)

#### 3. Path Matching
- Path prefix: `/recommendations`

#### 4. Traffic Split (Canary Deployment)
Implement weighted traffic distribution:
- **90%** → `stv-v1` (stable)
- **10%** → `stv-v2` (experimental)

Use `backendRefs` with `weight` to achieve this.

#### 5. Service Configuration
- Both services (`stv-v1` and `stv-v2`) listen on port **8080**
- Both services are in the `hawkins` namespace

#### 6. Save Location
Save the complete manifest to:
```bash
/root/st-canary.yaml
```


---

### ✅ Solution (Try yourself first!)

<details>
<summary>Click to reveal complete solution</summary>


### 📊 Understanding Canary Deployment

#### What is Canary Deployment?

A **canary deployment** gradually introduces a new version by routing a small percentage of traffic to it while most traffic stays on the stable version.

```
100 User Requests
       ↓
   [Gateway]
       ↓
  [HTTPRoute]
       ↓
   ┌───┴────┐
   ↓        ↓
  90%      10%
   ↓        ↓
[stv-v1] [stv-v2]
 Stable   Canary
```


#### Create the HTTPRoute

```bash
cat > /root/st-canary.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: stranger-canary-route
  namespace: hawkins
spec:
  parentRefs:
  - name: stranger-gw
    namespace: str-gtw
  hostnames:
  - "api.stranger.things"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/recommendations"
    backendRefs:
    - name: stv-v1
      port: 8080
      weight: 90
    - name: stv-v2
      port: 8080
      weight: 10
EOF
```

#### Apply the Configuration

```bash
kubectl apply -f /root/st-canary.yaml
```

#### Verify HTTPRoute

```bash
# Check HTTPRoute status
kubectl get httproute stranger-canary-route -n hawkins

# Detailed information
kubectl describe httproute stranger-canary-route -n hawkins

# Verify Gateway accepts the route
kubectl get gateway stranger-gw -n str-gtw -o yaml
```

#### Test

```bash
# View detailed responses
curl -s http://api.stranger.things/recommendations | jq
```

#### Monitor Traffic Distribution

```bash
# Watch both versions
kubectl logs -f deployment/stv-v1 -n hawkins &
kubectl logs -f deployment/stv-v2 -n hawkins &
```

</details>

