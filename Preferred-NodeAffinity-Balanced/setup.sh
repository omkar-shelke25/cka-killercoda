#!/bin/bash
set -euo pipefail

# Remove taint from controlplane to allow scheduling
kubectl taint no controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Create namespace
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
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
EOF

echo "✅ Setup complete! Check /app/app.yaml"
