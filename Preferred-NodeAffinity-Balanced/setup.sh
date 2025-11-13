#!/bin/bash
set -euo pipefail

# Create namespace first
kubectl create ns app

# Label both nodes with GPU labels
kubectl label no controlplane gpu.vendor=nvidia gpu.count=1
kubectl label no node01 gpu.vendor=nvidia gpu.count=1



# Create the app directory
mkdir -p /app

# Create the initial Deployment manifest with the issue (no affinity)
cat > /app/app.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: app-flask
  name: app-flask
  namespace: app
spec:
  replicas: 10
  selector:
    matchLabels:
      app: app-flask
  strategy: {}
  template:
    metadata:
      labels:
        app: app-flask
    spec:
      containers:
      - image: public.ecr.aws/docker/library/httpd:alpine
        name: httpd
        ports:
        - containerPort: 80
EOF

# Apply the deployment to show the problem (unbalanced distribution)
kubectl apply -f /app/app.yaml

sleep 15

kubectl taint no controlplane node-role.kubernetes.io/control-plane:NoSchedule-

echo "✅ Setup complete! Check /app/app.yaml"
echo "📊 Initial deployment applied - Pods may be unevenly distributed"
