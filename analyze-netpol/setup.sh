#!/bin/bash
set -euo pipefail

echo "🚀 Setting up NetworkPolicy analysis lab environment..."

# Create namespaces
kubectl create namespace frontend
kubectl create namespace backend
kubectl create namespace other

# Label namespaces for NetworkPolicy selection
kubectl label namespace frontend name=frontend
kubectl label namespace backend name=backend
kubectl label namespace other name=other

# Create ConfigMaps with HTML content

# Frontend HTML
kubectl create configmap frontend-html -n frontend --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Frontend Application</title></head>
<body style="background-color: #3498db; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🖥️ Frontend Application</h1>
    <p>Namespace: frontend</p>
    <p>This pod needs to communicate with backend service</p>
</body>
</html>'

# Backend HTML
kubectl create configmap backend-html -n backend --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Backend API</title></head>
<body style="background-color: #2ecc71; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>🔐 Backend API</h1>
    <p>Namespace: backend</p>
    <p>Port: 8080</p>
    <p>Should only accept traffic from frontend namespace</p>
</body>
</html>'

# Other namespace HTML
kubectl create configmap other-html -n other --from-literal=index.html='
<!DOCTYPE html>
<html>
<head><title>Other Application</title></head>
<body style="background-color: #e74c3c; color: white; font-family: Arial; text-align: center; padding: 50px;">
    <h1>⚠️ Other Application</h1>
    <p>Namespace: other</p>
    <p>This pod should NOT have access to backend</p>
</body>
</html>'

# Create nginx configuration for backend on port 8080
kubectl create configmap nginx-backend-conf -n backend --from-literal=default.conf='
server {
    listen 8080;
    server_name localhost;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}'

# Deploy Frontend Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
  labels:
    app: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: web
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
          name: frontend-html
EOF

# Deploy Backend Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: api
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
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: html
        configMap:
          name: backend-html
      - name: config
        configMap:
          name: nginx-backend-conf
EOF

# Deploy Other namespace pod (should not have access)
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
  name: frontend
  namespace: frontend
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: backend
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
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
kubectl wait --for=condition=available deployment/frontend -n frontend --timeout=120s
kubectl wait --for=condition=available deployment/backend -n backend --timeout=120s
kubectl wait --for=condition=available deployment/other-app -n other --timeout=120s

# Create directory for NetworkPolicy files
mkdir -p /root/network-policies

# Create NetworkPolicy option 1 (TOO PERMISSIVE - allows all namespaces)
cat > /root/network-policies/policy1.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
EOF

# Create NetworkPolicy option 2 (CORRECT - least permissive, namespace selector)
cat > /root/network-policies/policy2.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# Create NetworkPolicy option 3 (TOO PERMISSIVE - allows multiple ports)
cat > /root/network-policies/policy3.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 3000
EOF

# Create NetworkPolicy option 4 (WRONG - uses pod selector without namespace, too restrictive)
cat > /root/network-policies/policy4.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
EOF

# Create NetworkPolicy option 5 (TOO PERMISSIVE - allows all ingress to port 8080)
cat > /root/network-policies/policy5.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 8080
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Deployed resources:"
echo ""
echo "Namespaces:"
kubectl get namespaces frontend backend other
echo ""
echo "Frontend namespace:"
kubectl get deployments,pods,svc -n frontend
echo ""
echo "Backend namespace:"
kubectl get deployments,pods,svc -n backend
echo ""
echo "Other namespace:"
kubectl get deployments,pods,svc -n other
echo ""
echo "📁 NetworkPolicy files available in: /root/network-policies"
ls -1 /root/network-policies/
echo ""
echo "🎯 Your task: Analyze the NetworkPolicy files and deploy the correct one!"
echo "   Requirements:"
echo "   - Frontend pods must access backend pods"
echo "   - Only frontend namespace should have access"
echo "   - Only port 8080 should be allowed"
echo "   - Choose the LEAST PERMISSIVE policy"
echo ""
