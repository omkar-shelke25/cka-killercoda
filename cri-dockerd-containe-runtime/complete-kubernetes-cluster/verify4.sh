#!/bin/bash
set -e

echo "🔍 Verifying Step 4: Master Node Initialization..."
echo ""

# Check if kubectl config exists
echo "Checking kubectl configuration..."
if [ -f ~/.kube/config ]; then
    echo "✅ kubectl config file exists"
else
    echo "❌ kubectl config file not found"
    echo "   Run: mkdir -p \$HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
    exit 1
fi

# Check if kubectl can connect to cluster
echo "Checking cluster connectivity..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ kubectl can connect to the cluster"
else
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Verify that 'kubeadm init' completed successfully"
    exit 1
fi

# Check if control plane is initialized
echo "Checking control plane components..."
CONTROL_PLANE_PODS=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | wc -l)
if [ "$CONTROL_PLANE_PODS" -ge 3 ]; then
    echo "✅ Control plane components are running"
else
    echo "❌ Control plane components not found (found $CONTROL_PLANE_PODS pods)"
    exit 1
fi

# Check if etcd is running
echo "Checking etcd..."
if kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | grep -q "Running\|Pending"; then
    echo "✅ etcd is present"
else
    echo "⚠️  etcd pod not found (may still be starting)"
fi

# Check if API server is accessible
echo "Checking API server..."
if kubectl get --raw /healthz &> /dev/null; then
    echo "✅ API server is healthy"
else
    echo "❌ API server health check failed"
    exit 1
fi

# Check if node exists
echo "Checking master node registration..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODE_COUNT" -ge 1 ]; then
    NODE_NAME=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
    echo "✅ Master node registered (name: $NODE_NAME)"
else
    echo "❌ No nodes found in cluster"
    exit 1
fi

# Check if admin.conf exists
echo "Checking admin configuration..."
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✅ Admin configuration file exists"
else
    echo "❌ Admin configuration file not found"
    exit 1
fi

# Mark step as complete
touch /root/cluster-setup/.step4-complete

echo ""
echo "🎉 Step 4 verification passed!"
echo "✅ Control plane is initialized and kubectl is configured"
echo ""
echo "⚠️  Note: Node may show 'NotReady' status - this is expected before CNI installation"
echo ""
echo "Proceed to Step 5: Install Pod Network (CNI) ➡️"
