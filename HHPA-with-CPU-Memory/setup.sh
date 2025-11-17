#!/bin/bash
set -euo pipefail

echo "🔧 Setting up IoT Sensor API environment..."

kubectl taint no controlplane node-role.kubernetes.io/control-plane:NoSchedule-

sleep 5

# Create namespace
kubectl create ns iot-sys

# Install metrics-server
echo "📊 Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\,Hostname\,InternalDNS\,ExternalDNS,--metric-resolution=15s}" \
  --wait

sleep 5

# Create the deployment
cat > /tmp/sensor-api-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sensor-api
  namespace: iot-sys
  labels:
    app: sensor-api
    environment: production
  annotations:
    purpose: "production-deployment"
spec:
  replicas: 12
  selector:
    matchLabels:
      app: sensor-api
  template:
    metadata:
      labels:
        app: sensor-api
        environment: production
    spec:
      containers:
      - name: sensor-api
        image: public.ecr.aws/docker/library/httpd:trixie
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "512m"
            memory: "512Mi"
EOF

kubectl apply -f /tmp/sensor-api-deployment.yaml

# Create the service
cat > /tmp/sensor-api-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: sensor-api
  namespace: iot-sys
  labels:
    app: sensor-api
    environment: production
spec:
  selector:
    app: sensor-api
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF

kubectl apply -f /tmp/sensor-api-service.yaml

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/sensor-api -n iot-sys

# Create working directory
mkdir -p /iot-platform

echo "✅ Setup complete! Environment is ready."
echo ""
echo "📋 Current resources:"
kubectl get deploy,svc -n iot-sys
