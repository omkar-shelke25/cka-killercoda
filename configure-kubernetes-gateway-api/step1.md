## 🚄 Configure Kubernetes Gateway API for Bullet Train Services

📚 **Official Kubernetes Documentation**: [Gateway API](https://gateway-api.sigs.k8s.io/)

The Japan Railway (JR) has deployed three microservices in the `jp-bullet-train-app-prod` namespace:
- `available` - Real-time train availability
- `books` - Booking status
- `travellers` - Passenger manifest

Your task is to expose these services externally using the Kubernetes Gateway API with TLS termination and path-based routing.

---

### 🎯 Your Tasks:

#### Task 1: Create the Gateway

Create a **Gateway** named `bullet-train-gateway` in namespace `jp-bullet-train-gtw` with the following specifications:

- **Name**: `bullet-train-gateway`
- **Namespace**: `jp-bullet-train-gtw`
- **GatewayClassName**: `nginx`
- **Listener Configuration**:
  - Protocol: `HTTPS`
  - Port: `443`
  - Hostname: `bullet.train.io`
  - TLS Mode: `Terminate`
  - TLS Certificate: Reference the existing Secret `bullet-train-tls` in the same namespace

**Note**: The TLS secret `bullet-train-tls` has already been created in the `jp-bullet-train-gtw` namespace.

---

#### Task 2: Create the HTTPRoute

Create an **HTTPRoute** named `bullet-train-route` in namespace `jp-bullet-train-gtw` with path-based routing:

- **Name**: `bullet-train-route`
- **Namespace**: `jp-bullet-train-gtw`
- **Parent Gateway**: `bullet-train-gateway`
- **Hostname**: `bullet.train.io`
- **Routes**:
  1. Path `/available` → Service `available` (port 80) in namespace `jp-bullet-train-app-prod`
  2. Path `/books` → Service `books` (port 80) in namespace `jp-bullet-train-app-prod`
  3. Path `/travellers` → Service `travellers` (port 80) in namespace `jp-bullet-train-app-prod`
- **Path Match Type**: `PathPrefix` for all routes

**Important**: Since the HTTPRoute is in namespace `jp-bullet-train-gtw` but references services in `jp-bullet-train-app-prod`, you need cross-namespace routing. A ReferenceGrant has already been created to allow this.

---

#### Task 3: Verify Gateway and Get LoadBalancer IP

After creating the Gateway and HTTPRoute:

1. Check the Gateway status and verify it's **Programmed**
2. Get the **LoadBalancer IP** assigned to the Gateway service
3. Save the LoadBalancer IP to the file `/bullet-train/gateway-ip.txt`

---

#### Task 4: Configure Local DNS

To access the services via the domain name `bullet.train.io`:

1. Edit the `/etc/hosts` file
2. Add an entry mapping `bullet.train.io` to the Gateway's LoadBalancer IP
3. Test access to all three endpoints using `curl` with the `-k` flag (to skip certificate verification for self-signed cert)

---

#### Task 5: Validation Test

Create a shell script at `/bullet-train/test-endpoints.sh` that tests all three endpoints:

```bash
#!/bin/bash
echo "Testing Available Trains:"
curl -sk https://bullet.train.io/available | jq

echo -e "\nTesting Bookings:"
curl -sk https://bullet.train.io/books | jq

echo -e "\nTesting Travellers:"
curl -sk https://bullet.train.io/travellers | jq
```

Make the script executable and run it to verify all services are accessible.

---

### 📊 Expected Results

After completion, you should be able to:
- Access `https://bullet.train.io/available` and see train availability data
- Access `https://bullet.train.io/books` and see booking information
- Access `https://bullet.train.io/travellers` and see passenger data
- All traffic should be encrypted via HTTPS (TLS termination at the Gateway)

---

### 💡 Hints

<details><summary>Click to view hints</summary>

**Hint 1 - Gateway Structure**:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: <gateway-name>
  namespace: <namespace>
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: <hostname>
    tls:
      mode: Terminate
      certificateRefs:
      - name: <secret-name>
```

**Hint 2 - HTTPRoute Structure**:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <route-name>
  namespace: <namespace>
spec:
  parentRefs:
  - name: <gateway-name>
  hostnames:
  - <hostname>
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /path
    backendRefs:
    - name: <service-name>
      namespace: <service-namespace>
      port: 80
```

**Hint 3 - Getting LoadBalancer IP**:
```bash
kubectl get gateway <gateway-name> -n <namespace> -o jsonpath='{.status.addresses[0].value}'
```

**Hint 4 - Editing /etc/hosts**:
```bash
echo "<IP-ADDRESS> bullet.train.io" | sudo tee -a /etc/hosts
```

</details>

---

### ✅ Solution (Try it yourself first!)

<details><summary>Click to view complete solution</summary>

#### Step 1: Create the Gateway

```bash
cat > /tmp/gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bullet-train-gateway
  namespace: jp-bullet-train-gtw
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: bullet.train.io
    tls:
      mode: Terminate
      certificateRefs:
      - name: bullet-train-tls
EOF

kubectl apply -f /tmp/gateway.yaml
```

#### Step 2: Create the HTTPRoute

```bash
cat > /tmp/httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bullet-train-route
  namespace: jp-bullet-train-gtw
spec:
  parentRefs:
  - name: bullet-train-gateway
  hostnames:
  - bullet.train.io
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /available
    backendRefs:
    - name: available
      namespace: jp-bullet-train-app-prod
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /books
    backendRefs:
    - name: books
      namespace: jp-bullet-train-app-prod
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /travellers
    backendRefs:
    - name: travellers
      namespace: jp-bullet-train-app-prod
      port: 80
EOF

kubectl apply -f /tmp/httproute.yaml
```

#### Step 3: Verify and Get LoadBalancer IP

```bash
# Check Gateway status
kubectl get gateway bullet-train-gateway -n jp-bullet-train-gtw

# Get detailed status
kubectl describe gateway bullet-train-gateway -n jp-bullet-train-gtw

# Get LoadBalancer IP
GATEWAY_IP=$(kubectl get svc -n nginx-gateway -l gateway.networking.k8s.io/gateway-name=bullet-train-gateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Save to file
echo $GATEWAY_IP > /bullet-train/gateway-ip.txt

# Display IP
echo "Gateway IP: $GATEWAY_IP"
```

#### Step 4: Configure /etc/hosts

```bash
# Get the IP
GATEWAY_IP=$(cat /bullet-train/gateway-ip.txt)

# Add to /etc/hosts
echo "$GATEWAY_IP bullet.train.io" | sudo tee -a /etc/hosts

# Verify
cat /etc/hosts | grep bullet.train.io
```

#### Step 5: Create and Run Test Script

```bash
cat > /bullet-train/test-endpoints.sh <<'EOF'
#!/bin/bash
echo "🚄 Testing Available Trains Endpoint:"
curl -sk https://bullet.train.io/available | jq
echo ""

echo "📕 Testing Bookings Endpoint:"
curl -sk https://bullet.train.io/books | jq
echo ""

echo "🛂 Testing Travellers Endpoint:"
curl -sk https://bullet.train.io/travellers | jq
echo ""

echo "✅ All endpoints tested!"
EOF

chmod +x /bullet-train/test-endpoints.sh
/bullet-train/test-endpoints.sh
```

#### Alternative: Test Manually

```bash
# Test each endpoint
curl -sk https://bullet.train.io/available | jq
curl -sk https://bullet.train.io/books | jq
curl -sk https://bullet.train.io/travellers | jq
```

#### Verification Commands

```bash
# Check Gateway status
kubectl get gateway -n jp-bullet-train-gtw

# Check HTTPRoute status
kubectl get httproute -n jp-bullet-train-gtw

# Check all resources
kubectl get gateway,httproute -n jp-bullet-train-gtw

# View HTTPRoute details
kubectl describe httproute bullet-train-route -n jp-bullet-train-gtw
```

</details>
