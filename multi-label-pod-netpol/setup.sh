#!/bin/bash
set -euo pipefail

echo "🚀 Setting up NetworkPolicy lab environment..."

NS="isolated"

# Create the isolated namespace (idempotent)
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

# Create ConfigMaps with different HTML content for each pod type.
# Using --dry-run=client -o yaml | kubectl apply -f - instead of 'kubectl create'
# so this script is safe to re-run (create fails with AlreadyExists otherwise).

# API pod content - listens on port 7000
kubectl create configmap api-html -n "$NS" --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>API Service</title></head>
<body style="background-color: #2ecc71; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🔐 API Service</h1>
    <p>Port: 7000</p>
    <p>Label: app=api</p>
    <p>This service should only accept traffic from pods with BOTH labels:</p>
    <ul style="list-style: none;">
        <li>✓ app=frontend</li>
        <li>✓ role=proxy</li>
    </ul>
</body>
</html>' --dry-run=client -o yaml | kubectl apply -f -

# API pod content on port 8080 (should NOT be accessible)
kubectl create configmap api-alt-html -n "$NS" --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>API Alternative Port</title></head>
<body style="background-color: #e74c3c; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>⚠️ API Alternative Port</h1>
    <p>Port: 8080</p>
    <p>This port should NOT be accessible per NetworkPolicy!</p>
</body>
</html>' --dry-run=client -o yaml | kubectl apply -f -

# Frontend pod content
kubectl create configmap frontend-html -n "$NS" --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Frontend Service</title></head>
<body style="background-color: #3498db; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🖥️ Frontend Service</h1>
    <p>Labels: app=frontend, role=proxy</p>
    <p>This pod should be able to access API service</p>
</body>
</html>' --dry-run=client -o yaml | kubectl apply -f -

# Frontend-only pod (missing role=proxy label)
kubectl create configmap frontend-only-html -n "$NS" --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Frontend Only</title></head>
<body style="background-color: #9b59b6; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🚫 Frontend Only</h1>
    <p>Label: app=frontend (missing role=proxy)</p>
    <p>This pod should NOT be able to access API service</p>
</body>
</html>' --dry-run=client -o yaml | kubectl apply -f -

# Database pod content
kubectl create configmap database-html -n "$NS" --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Database Service</title></head>
<body style="background-color: #34495e; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🗄️ Database Service</h1>
    <p>Label: app=database</p>
    <p>This pod should NOT be able to access API service</p>
</body>
</html>' --dry-run=client -o yaml | kubectl apply -f -

# Create nginx configuration for custom ports
kubectl create configmap nginx-7000-conf -n "$NS" --from-literal=default.conf='
server {
    listen 7000;
    server_name localhost;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}' --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap nginx-8080-conf -n "$NS" --from-literal=default.conf='
server {
    listen 8080;
    server_name localhost;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}' --dry-run=client -o yaml | kubectl apply -f -

# Deploy API pod on port 7000 (target pod)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: api-pod
  namespace: $NS
  labels:
    app: api
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 7000
      name: api-port
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
    - name: config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: html
    configMap:
      name: api-html
  - name: config
    configMap:
      name: nginx-7000-conf
EOF

# Deploy API pod on port 8080 (should be blocked by NetworkPolicy)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: api-pod-alt
  namespace: $NS
  labels:
    app: api
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 8080
      name: alt-port
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
    - name: config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: html
    configMap:
      name: api-alt-html
  - name: config
    configMap:
      name: nginx-8080-conf
EOF

# Deploy frontend pod with BOTH required labels (should have access)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend-proxy-pod
  namespace: $NS
  labels:
    app: frontend
    role: proxy
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  volumes:
  - name: html
    configMap:
      name: frontend-html
EOF

# Deploy frontend pod with ONLY app=frontend label (should NOT have access)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend-only-pod
  namespace: $NS
  labels:
    app: frontend
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  volumes:
  - name: html
    configMap:
      name: frontend-only-html
EOF

# Deploy database pod (should NOT have access)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: database-pod
  namespace: $NS
  labels:
    app: database
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
  volumes:
  - name: html
    configMap:
      name: database-html
EOF

# Wait for all pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all -n "$NS" --timeout=120s

# Create ClusterIP Services to expose the pods
echo ""
echo "🌐 Creating ClusterIP services..."

# Service for api-pod (port 7000)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-pod
  namespace: $NS
spec:
  selector:
    app: api
  ports:
  - name: api-port
    protocol: TCP
    port: 7000
    targetPort: 7000
  type: ClusterIP
EOF

# Service for api-pod-alt (port 8080)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-pod-alt
  namespace: $NS
spec:
  selector:
    app: api
  ports:
  - name: alt-port
    protocol: TCP
    port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

# Service for frontend-proxy-pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-proxy-pod
  namespace: $NS
spec:
  selector:
    app: frontend
    role: proxy
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Service for frontend-only-pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-only-pod
  namespace: $NS
spec:
  selector:
    app: frontend
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Service for database-pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: database-pod
  namespace: $NS
spec:
  selector:
    app: database
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Display pod and service information
echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Created pods in '$NS' namespace:"
kubectl get pods -n "$NS" -o wide --show-labels
echo ""
echo "🌐 Created services in '$NS' namespace:"
kubectl get svc -n "$NS"
echo ""
echo "🎯 Your task: Create NetworkPolicy 'allow-multi-pod-ingress' that allows traffic to app=api pods"
echo "   Only from pods with BOTH labels: app=frontend AND role=proxy"
echo "   Only to TCP port 7000"
echo ""
