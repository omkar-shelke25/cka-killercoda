#!/bin/bash
set -euo pipefail

echo "🚀 Setting up CoreDNS configuration lab environment..."

# Create directory for backups
mkdir -p /opt/course/16

# Wait for CoreDNS to be ready
echo "⏳ Waiting for CoreDNS to be ready..."
kubectl wait --for=condition=available deployment/coredns -n kube-system --timeout=120s

# Create a test namespace and service for verification
kubectl create namespace test-dns

# Deploy a simple service for DNS testing
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: test-dns
spec:
  selector:
    app: test
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: test-dns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Wait for test deployment
kubectl wait --for=condition=available deployment/test-deployment -n test-dns --timeout=60s

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Current CoreDNS status:"
kubectl get deployment coredns -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns
echo ""
echo "🎯 Your mission:"
echo "   1. Backup CoreDNS ConfigMap to /opt/course/16/coredns_backup.yaml"
echo "   2. Add custom domain 'killercoda.com' ALONGSIDE cluster.local"
echo "   3. Test DNS resolution for BOTH domains (both must work)"
echo ""
echo "📝 Important:"
echo "   - Do NOT replace cluster.local - add killercoda.com alongside it"
echo "   - Both domains must work simultaneously"
echo "   - Both domains should resolve to the same IP addresses"
echo ""
echo "🧪 Test commands (BOTH should work after configuration):"
echo "   kubectl run test-dns --image=busybox:1.35 -it --rm -- nslookup kubernetes.default.svc.cluster.local"
echo "   kubectl run test-dns --image=busybox:1.35 -it --rm -- nslookup kubernetes.default.svc.killercoda.com"
echo ""
