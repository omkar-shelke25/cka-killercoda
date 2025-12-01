#!/bin/bash
set -euo pipefail

echo "🚄 Setting up Japan Bullet Train Booking System..."

# Install Gateway API CRDs
echo "📦 Installing Kubernetes Gateway API CRDs..."
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1

# Install NGINX Gateway Fabric
echo "🔌 Installing NGINX Gateway Fabric..."
helm repo add nginx-stable https://helm.nginx.com/stable > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --wait > /dev/null 2>&1

# Install MetalLB for LoadBalancer support
echo "🔧 Installing MetalLB for LoadBalancer support..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml > /dev/null 2>&1

echo "⏳ Waiting for MetalLB to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=component=controller \
  --timeout=120s > /dev/null 2>&1 || echo "Waiting for MetalLB..."

sleep 5

echo "🌐 Configuring MetalLB IP Address Pool..."
cat <<'YAML' | kubectl apply -f - > /dev/null 2>&1
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-address-pool
YAML

sleep 5

# Create application namespace
echo "🏗️  Creating application namespace..."
kubectl create namespace jp-bullet-train-app-prod > /dev/null 2>&1 || true

# Deploy the three microservices
echo "🚅 Deploying Bullet Train microservices..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Namespace
metadata:
  name: jp-bullet-train-app-prod
---
# 1. AVAILABLE TRAINS SERVICE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: available
  namespace: jp-bullet-train-app-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: available
  template:
    metadata:
      labels:
        app: available
    spec:
      containers:
      - name: server
        image: python:3.11-slim
        ports: [{ containerPort: 8080 }]
        resources:
          requests: { memory: "64Mi", cpu: "50m" }
          limits:   { memory: "128Mi", cpu: "200m" }
        command: ["python", "-c"]
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          data = {
            "endpoint": "available",
            "message": "Available Trains Service - 8 trains ready for booking",
            "trains": 8
          }
          class H(BaseHTTPRequestHandler):
            def do_GET(s):
              s.send_response(200)
              s.send_header("Content-Type", "application/json")
              s.end_headers()
              s.wfile.write(json.dumps(data, indent=2).encode())
          HTTPServer(("",8080),H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: available
  namespace: jp-bullet-train-app-prod
spec:
  selector: { app: available }
  ports: [{ port: 80, targetPort: 8080 }]

---
# 2. BOOKINGS SERVICE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: books
  namespace: jp-bullet-train-app-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: books
  template:
    metadata:
      labels:
        app: books
    spec:
      containers:
      - name: server
        image: python:3.11-slim
        ports: [{ containerPort: 8080 }]
        resources:
          requests: { memory: "64Mi", cpu: "50m" }
          limits:   { memory: "128Mi", cpu: "200m" }
        command: ["python", "-c"]
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          data = {
            "endpoint": "books",
            "message": "Booking Service - 8,459 total bookings",
            "bookings": 8459
          }
          class H(BaseHTTPRequestHandler):
            def do_GET(s):
              s.send_response(200)
              s.send_header("Content-Type", "application/json")
              s.end_headers()
              s.wfile.write(json.dumps(data, indent=2).encode())
          HTTPServer(("",8080),H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: books
  namespace: jp-bullet-train-app-prod
spec:
  selector: { app: books }
  ports: [{ port: 80, targetPort: 8080 }]

---
# 3. TRAVELLERS SERVICE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: travellers
  namespace: jp-bullet-train-app-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: travellers
  template:
    metadata:
      labels:
        app: travellers
    spec:
      containers:
      - name: server
        image: python:3.11-slim
        ports: [{ containerPort: 8080 }]
        resources:
          requests: { memory: "64Mi", cpu: "50m" }
          limits:   { memory: "128Mi", cpu: "200m" }
        command: ["python", "-c"]
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          data = {
            "endpoint": "travellers",
            "message": "Travellers Service - 12 active passengers",
            "travellers": 12
          }
          class H(BaseHTTPRequestHandler):
            def do_GET(s):
              s.send_response(200)
              s.send_header("Content-Type", "application/json")
              s.end_headers()
              s.wfile.write(json.dumps(data, indent=2).encode())
          HTTPServer(("",8080),H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: travellers
  namespace: jp-bullet-train-app-prod
spec:
  selector: { app: travellers }
  ports: [{ port: 80, targetPort: 8080 }]
EOF

# Wait for deployments to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/available -n jp-bullet-train-app-prod --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/books -n jp-bullet-train-app-prod --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/travellers -n jp-bullet-train-app-prod --timeout=120s > /dev/null 2>&1

# Create gateway namespace
echo "🏗️  Creating gateway namespace..."
kubectl create namespace jp-bullet-train-gtw > /dev/null 2>&1 || true

# Create a self-signed TLS certificate
echo "🔐 Creating TLS certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=bullet.train.io/O=JR-Railway" > /dev/null 2>&1

# Create TLS secret in gateway namespace
kubectl create secret tls bullet-train-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n jp-bullet-train-gtw > /dev/null 2>&1 || true

# Create GatewayClass if not exists
echo "🎓 Creating GatewayClass..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
EOF

# Create reference grant for cross-namespace access
echo "🔗 Creating ReferenceGrant for cross-namespace routing..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-services
  namespace: jp-bullet-train-app-prod
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: jp-bullet-train-gtw
  to:
  - group: ""
    kind: Service
EOF

# Create task directory
mkdir -p /bullet-train

echo "✅ Setup complete! Japan Bullet Train Booking System is ready."
echo ""
echo "📋 Environment Overview:"
echo "   • Gateway Namespace: jp-bullet-train-gtw"
echo "   • Application Namespace: jp-bullet-train-app-prod"
echo "   • Services: available, books, travellers"
echo "   • TLS Secret: bullet-train-tls (already created)"
echo ""
echo "🎯 Your task: Configure Gateway and HTTPRoute to expose services at:"
echo "   • https://bullet.train.io/available"
echo "   • https://bullet.train.io/books"
echo "   • https://bullet.train.io/travellers"
