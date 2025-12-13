#!/bin/bash
set -euo pipefail

echo "Simulating disaster recovery scenario..."
echo ""



# Step 1: Simulate disaster recovery issue - change etcd client port from 2379 to peer port 2380
echo "Simulating disaster recovery configuration error..."
echo "Changing etcd client port from 2379 (correct) to 2380 (incorrect - peer port)..."
sudo sed -i 's/:2379/:2380/g' /etc/kubernetes/manifests/kube-apiserver.yaml

# Wait for kubelet to detect the change
sleep 5

# Step 2: Show kube-apiserver pod status/logs
echo ""
echo "⚠️  Disaster recovery complete - but something went wrong!"
echo ""
echo "🔍 Checking kube-apiserver status..."

# Try to find the kube-apiserver container
KAPISERVER_ID=$(sudo crictl ps -a | grep kube-apiserver | awk '{print $1}' | head -n 1 || echo "")

if [ -n "$KAPISERVER_ID" ]; then
    echo ""
    echo "📋 Recent kube-apiserver logs (last 15 lines):"
    sudo crictl logs "$KAPISERVER_ID" 2>&1 | tail -n 15 || echo "Could not retrieve logs"
else
    echo "⚠️  kube-apiserver container not found or not running"
fi

# Step 3: Verify that kubectl fails as API server is down
echo ""
echo "🔍 Testing cluster connectivity..."
if kubectl get nodes 2>&1; then
    echo "✓ Cluster is accessible (unexpected)"
else
    echo ""
    echo "❌ As expected: API server is down due to misconfigured etcd connection"
fi

