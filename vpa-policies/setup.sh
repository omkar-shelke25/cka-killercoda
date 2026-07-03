#!/bin/bash
set -euo pipefail

echo "Setting up the VPA scenario environment..."

# Wait for cluster to be ready
kubectl wait --for=condition=ready node --all --timeout=120s || true

# Install VPA components
echo "Installing Vertical Pod Autoscaler..."

# Clone VPA repository
cd /root
if [[ ! -d /root/autoscaler ]]; then
  git clone https://github.com/kubernetes/autoscaler.git || echo "Clone failed, may already exist"
fi

if [[ -d /root/autoscaler/vertical-pod-autoscaler ]]; then
  cd /root/autoscaler/vertical-pod-autoscaler
  # Install VPA
  ./hack/vpa-up.sh || echo "VPA installation may have partially completed"
fi

# Wait for VPA components to be ready (ignore failures)
echo "Waiting for VPA components to be ready..."
kubectl wait --for=condition=available deployment/vpa-admission-controller -n kube-system --timeout=120s || true
kubectl wait --for=condition=available deployment/vpa-recommender -n kube-system --timeout=120s || true
kubectl wait --for=condition=available deployment/vpa-updater -n kube-system --timeout=120s || true

# Create a namespace for the application
kubectl create namespace vpa-demo --dry-run=client -o yaml | kubectl apply -f -

# Create a deployment with a container named "application"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: vpa-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: application
  template:
    metadata:
      labels:
        app: application
    spec:
      containers:
      - name: application
        image: nginx:alpine
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

# Wait for deployment to be ready
kubectl wait --for=condition=available deployment/app-deployment -n vpa-demo --timeout=120s || true

# Verify deployment exists
if kubectl get deployment app-deployment -n vpa-demo &>/dev/null; then
  echo ""
  echo "Setup complete."
  echo ""
  echo "Environment details:"
  echo "  - VPA components installed in kube-system namespace"
  echo "  - Deployment 'app-deployment' created in 'vpa-demo' namespace"
  echo "  - Container name: 'application'"
  echo "  - Current resources: 50m CPU / 64Mi memory (requests), 100m CPU / 128Mi memory (limits)"
  echo ""
  echo "Your task: Create a VPA that will manage this deployment's resources"
  echo ""
else
  echo ""
  echo "WARNING: Deployment app-deployment was not created successfully."
  echo "You may need to create it manually before proceeding."
  echo ""
fi
