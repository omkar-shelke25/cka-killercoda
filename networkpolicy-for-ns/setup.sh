#!/bin/bash
set -euo pipefail

echo "🔒 Setting up NetworkPolicy Environment..."
echo ""

# Create namespaces
echo "🏗️ Creating namespaces..."
kubectl create namespace fubar > /dev/null 2>&1 || true
kubectl create namespace internal > /dev/null 2>&1 || true
kubectl create namespace external > /dev/null 2>&1 || true

# Create ConfigMaps for different services
echo "📝 Creating ConfigMaps..."

# ConfigMap for service on port 9000
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-9000-html
  namespace: fubar
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Secure Service - Port 9000</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px; background: #e8f5e9;">
      <h1>🔒 Secure Service</h1>
      <h2>Port 9000 - Protected</h2>
      <p>This service should only be accessible from 'internal' namespace</p>
      <p style="color: green;">✅ Access Granted</p>
    </body>
    </html>
  nginx.conf: |
    events {}
    http {
      server {
        listen 9000;
        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
      }
    }
EOF

# ConfigMap for service on port 8080
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-8080-html
  namespace: fubar
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Public Service - Port 8080</title></head>
    <body style="font-family: Arial; text-align: center; padding: 50px; background: #ffebee;">
      <h1>🌐 Public Service</h1>
      <h2>Port 8080 - Should Be Blocked</h2>
      <p>This service should NOT be accessible (wrong port)</p>
      <p style="color: red;">❌ Should Be Denied</p>
    </body>
    </html>
  nginx.conf: |
    events {}
    http {
      server {
        listen 8080;
        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
      }
    }
EOF

# Deploy service on port 9000 in fubar namespace
echo "🚀 Deploying app-9000 in fubar namespace..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-9000
  namespace: fubar
  labels:
    app: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
      port: "9000"
  template:
    metadata:
      labels:
        app: secure-app
        port: "9000"
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 9000
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: html
        configMap:
          name: app-9000-html
      - name: config
        configMap:
          name: app-9000-html
---
apiVersion: v1
kind: Service
metadata:
  name: app-9000-service
  namespace: fubar
spec:
  type: ClusterIP
  selector:
    app: secure-app
    port: "9000"
  ports:
  - port: 9000
    targetPort: 9000
EOF

# Deploy service on port 8080 in fubar namespace
echo "🚀 Deploying app-8080 in fubar namespace..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-8080
  namespace: fubar
  labels:
    app: public-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: public-app
      port: "8080"
  template:
    metadata:
      labels:
        app: public-app
        port: "8080"
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: html
        configMap:
          name: app-8080-html
      - name: config
        configMap:
          name: app-8080-html
---
apiVersion: v1
kind: Service
metadata:
  name: app-8080-service
  namespace: fubar
spec:
  type: ClusterIP
  selector:
    app: public-app
    port: "8080"
  ports:
  - port: 8080
    targetPort: 8080
EOF

# Create test pod in internal namespace
echo "🧪 Creating test pod in internal namespace..."
kubectl run internal-client -n internal --image=busybox --command -- sleep 3600 > /dev/null 2>&1 || true

# Create test pod in external namespace
echo "🧪 Creating test pod in external namespace..."
kubectl run external-client -n external --image=busybox --command -- sleep 3600 > /dev/null 2>&1 || true

# Wait for pods
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/app-9000 -n fubar --timeout=60s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/app-8080 -n fubar --timeout=60s > /dev/null 2>&1
kubectl wait --for=condition=ready pod/internal-client -n internal --timeout=60s > /dev/null 2>&1
kubectl wait --for=condition=ready pod/external-client -n external --timeout=60s > /dev/null 2>&1

echo ""
echo "=========================================================================="
echo "   NETWORKPOLICY CONFIGURATION CHALLENGE"
echo "=========================================================================="
echo ""
echo "ENVIRONMENT SETUP:"
echo "   - Namespace 'fubar': Contains protected services"
echo "   - Namespace 'internal': Contains authorized clients"
echo "   - Namespace 'external': Contains unauthorized clients"
echo ""
echo "SERVICES IN FUBAR:"
kubectl get svc -n fubar
echo ""
echo "TEST PODS:"
kubectl get pods -n internal
kubectl get pods -n external
echo ""
echo "YOUR TASK:"
echo ""
echo "Create a NetworkPolicy named 'allow-port-from-namespace' in namespace 'fubar' that:"
echo "   1. Allows traffic from 'internal' namespace ONLY"
echo "   2. Allows traffic to TCP port 9000 ONLY"
echo "   3. Blocks traffic to other ports (e.g., 8080)"
echo "   4. Blocks traffic from other namespaces (e.g., 'external')"
echo ""
echo "EXPECTED BEHAVIOR AFTER NETWORKPOLICY:"
echo "   ✅ internal-client → app-9000-service:9000 (ALLOWED)"
echo "   ❌ internal-client → app-8080-service:8080 (BLOCKED)"
echo "   ❌ external-client → app-9000-service:9000 (BLOCKED)"
echo "   ❌ external-client → app-8080-service:8080 (BLOCKED)"
echo ""
echo "TIME LIMIT: 8-10 minutes"
echo ""
echo "=========================================================================="
