#!/bin/bash
set -euo pipefail

echo "🚀 Setting up CKA Storage Challenge..."

# Create the operations namespace
kubectl create namespace operations

# Create directory structure for storing manifests
mkdir -p /src/k8s

# Create the initial Deployment manifest (without PVC)
cat > /src/k8s/image-processor.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-processor
  namespace: operations
  labels:
    app: image-processor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-processor
  template:
    metadata:
      labels:
        app: image-processor
    spec:
      containers:
      - name: processor
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            echo "Image processor starting..."
            echo "Waiting for work..."
            while true; do
              sleep 3600
            done
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF


kubectl apply -f /src/k8s/image-processor.yaml


echo "✅ Setup complete!"
echo ""
echo "📁 Resources created:"
echo "   - Namespace: operations"
echo "   - StorageClass: local-path (from Rancher Local Path Provisioner)"
echo "   - Deployment manifest: /src/k8s/image-processor.yaml"
echo ""
echo "🎯 You can now begin the challenge!"
