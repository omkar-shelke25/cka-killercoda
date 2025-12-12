#!/bin/bash
set -euo pipefail

echo "🦸 Setting up U.A. High School Hero Registration Portal..."
echo ""

# Install NGINX Ingress Controller
echo "🔧 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml > /dev/null 2>&1

echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s > /dev/null 2>&1 || echo "Ingress controller initializing..."

sleep 5

# Install MetalLB for LoadBalancer support
echo "🔧 Installing MetalLB..."
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

# Create class-1a namespace
echo "🏗️ Creating class-1a namespace..."
kubectl create namespace class-1a > /dev/null 2>&1 || true

# Create TLS certificate
echo "🔒 Creating TLS certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=heroes.ua-academy.com/O=UA-High-School" > /dev/null 2>&1

kubectl create secret tls ua-heroes-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n class-1a > /dev/null 2>&1 || true

# Create register-service
echo "🚀 Creating register-service..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: register-service
  namespace: class-1a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: register
  template:
    metadata:
      labels:
        app: register
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: register-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: register-html
  namespace: class-1a
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Hero Registration</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px;">
      <h1>🦸 U.A. High School</h1>
      <h2>Hero Registration Portal</h2>
      <p>Service: <strong>register-service</strong></p>
      <p>Status: <strong>✅ Online</strong></p>
      <p>Register your hero quirk and abilities here!</p>
      <p style="color: green;">Plus Ultra! 💪</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: register-service
  namespace: class-1a
spec:
  type: ClusterIP
  selector:
    app: register
  ports:
  - port: 80
    targetPort: 80
EOF

# Create verify-service
echo "🚀 Creating verify-service..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: verify-service
  namespace: class-1a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: verify
  template:
    metadata:
      labels:
        app: verify
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: verify-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: verify-html
  namespace: class-1a
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Hero Verification</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px;">
      <h1>🦸 U.A. High School</h1>
      <h2>Hero Verification Portal</h2>
      <p>Service: <strong>verify-service</strong></p>
      <p>Status: <strong>✅ Online</strong></p>
      <p>Verify your hero license and credentials here!</p>
      <p style="color: blue;">Plus Ultra! 💪</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: verify-service
  namespace: class-1a
spec:
  type: ClusterIP
  selector:
    app: verify
  ports:
  - port: 80
    targetPort: 80
EOF

# Wait for deployments
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/register-service -n class-1a --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/verify-service -n class-1a --timeout=120s > /dev/null 2>&1

echo ""
echo "=========================================================================="
echo "   U.A. HIGH SCHOOL - HERO REGISTRATION PORTAL"
echo "=========================================================================="
echo ""
echo "ENVIRONMENT READY:"
echo "   - Namespace: class-1a"
echo "   - Services: register-service, verify-service"
echo "   - TLS Secret: ua-heroes-tls"
echo "   - Hostname: heroes.ua-academy.com"
echo ""
echo "YOUR TASK:"
echo ""
echo "Create an Ingress named 'hero-reg-ingress' that:"
echo "   1. Uses TLS termination with secret 'ua-heroes-tls'"
echo "   2. Routes /register to register-service:80"
echo "   3. Routes /verify to verify-service:80"
echo "   4. Hostname: heroes.ua-academy.com"
echo ""
echo "SERVICES STATUS:"
kubectl get svc -n class-1a
echo ""
echo "TLS SECRET:"
kubectl get secret ua-heroes-tls -n class-1a
echo ""
echo "TIME LIMIT: 6-8 minutes"
echo "Plus Ultra! 💪"
echo ""
echo "=========================================================================="
