#!/bin/bash
set -euo pipefail

echo "🚀 Setting up Egress NetworkPolicy lab environment..."

# Create namespaces
kubectl create namespace restricted
kubectl create namespace data
kubectl create namespace cache
kubectl create namespace other

# Label namespaces for NetworkPolicy selection
kubectl label namespace restricted name=restricted
kubectl label namespace data name=data
kubectl label namespace cache name=cache
kubectl label namespace other name=other

# Create ConfigMaps with HTML content

# Restricted namespace app HTML
kubectl create configmap app-html -n restricted --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Application Pod</title></head>
<body style="background-color: #3498db; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>📱 Application Pod</h1>
    <p>Namespace: restricted</p>
    <p>Should be able to access database OR cache</p>
    <p>Should NOT access other destinations</p>
</body>
</html>'

# Database HTML
kubectl create configmap database-html -n data --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Database Service</title></head>
<body style="background-color: #2ecc71; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🗄️ Database Service</h1>
    <p>Namespace: data</p>
    <p>Label: app=database</p>
    <p>Port: 5432</p>
    <p>Should accept traffic from restricted namespace</p>
</body>
</html>'

# Cache HTML
kubectl create configmap cache-html -n cache --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Cache Service</title></head>
<body style="background-color: #e67e22; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>💾 Cache Service</h1>
    <p>Namespace: cache</p>
    <p>Label: role=cache</p>
    <p>Port: 5432</p>
    <p>Should accept traffic from restricted namespace</p>
</body>
</html>'

# Other namespace HTML
kubectl create configmap other-html -n other --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Other Service</title></head>
<body style="background-color: #e74c3c; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>⚠️ Other Service</h1>
    <p>Namespace: other</p>
    <p>Should NOT receive traffic from restricted namespace</p>
</body>
</html>'

# Create nginx configuration for port 5432
kubectl create configmap nginx-5432-conf -n data --from-literal=default.conf='
server {
    listen 5432;
    server_name localhost;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}'

kubectl create configmap nginx-5432-conf -n cache --from-literal=default.conf='
server {
    listen 5432;
    server_name localhost;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}'

# Deploy Application in restricted namespace
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: restricted
  labels:
    app: application
spec:
  replicas: 2
  selector:
    matchLabels:
      app: application
  template:
    metadata:
      labels:
        app: application
        tier: frontend
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
          name: app-html
EOF

# Deploy Database in data namespace
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: data
  labels:
    app: database
spec:
  replicas: 2
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        tier: data
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: html
        configMap:
          name: database-html
      - name: config
        configMap:
          name: nginx-5432-conf
EOF

# Deploy Cache in cache namespace
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: cache
  labels:
    app: cache
spec:
  replicas: 2
  selector:
    matchLabels:
      role: cache
  template:
    metadata:
      labels:
        role: cache
        tier: cache
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: html
        configMap:
          name: cache-html
      - name: config
        configMap:
          name: nginx-5432-conf
EOF

# Deploy Other service (should be blocked)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: other-app
  namespace: other
  labels:
    app: other
spec:
  replicas: 1
  selector:
    matchLabels:
      app: other
  template:
    metadata:
      labels:
        app: other
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
          name: other-html
EOF

# Create Services
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: app
  namespace: restricted
spec:
  selector:
    app: application
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: data
spec:
  selector:
    app: database
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: cache
  namespace: cache
spec:
  selector:
    role: cache
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: other-app
  namespace: other
spec:
  selector:
    app: other
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/app -n restricted --timeout=120s
kubectl wait --for=condition=available deployment/database -n data --timeout=120s
kubectl wait --for=condition=available deployment/cache -n cache --timeout=120s
kubectl wait --for=condition=available deployment/other-app -n other --timeout=120s

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Deployed resources:"
echo ""
echo "Restricted namespace (source):"
kubectl get deployments,pods,svc -n restricted
echo ""
echo "Data namespace (database - destination 1):"
kubectl get deployments,pods,svc -n data
echo ""
echo "Cache namespace (cache - destination 2):"
kubectl get deployments,pods,svc -n cache
echo ""
echo "Other namespace (should be blocked):"
kubectl get deployments,pods,svc -n other
echo ""
echo "🎯 Your task: Create egress NetworkPolicy 'allow-egress-or-logic' in 'restricted' namespace"
echo "   Requirements:"
echo "   - Allow egress to app=database pods in data namespace (port 5432)"
echo "   - OR allow egress to role=cache pods in cache namespace (port 5432)"
echo "   - Allow DNS to kube-dns in kube-system (UDP/TCP port 53)"
echo "   - Block all other egress traffic"
echo ""
