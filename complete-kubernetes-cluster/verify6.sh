#!/bin/bash
set -e

echo "🔍 Verifying Step 6: Worker Node Management..."
echo ""

# Check if tokens can be generated
echo "Checking token generation capability..."
if kubeadm token create --dry-run=true &> /dev/null; then
    echo "✅ Token generation capability verified"
else
    echo "❌ Cannot generate tokens"
    exit 1
fi

# List current tokens
echo "Checking for active tokens..."
TOKEN_COUNT=$(kubeadm token list --kubeconfig /etc/kubernetes/admin.conf | tail -n +2 | wc -l)
echo "✅ Active tokens: $TOKEN_COUNT"

# Check if CA cert exists
echo "Checking CA certificate..."
if [ -f /etc/kubernetes/pki/ca.crt ]; then
    echo "✅ CA certificate exists"
else
    echo "❌ CA certificate not found"
    exit 1
fi

# Verify we can extract CA cert hash
echo "Verifying CA cert hash extraction..."
CA_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
   openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //')
if [ -n "$CA_HASH" ]; then
    echo "✅ CA certificate hash can be extracted"
else
    echo "❌ Failed to extract CA certificate hash"
    exit 1
fi

# Check node count
echo "Checking cluster nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "✅ Nodes in cluster: $NODE_COUNT"

# Check if all nodes are Ready
echo "Checking node readiness..."
NOT_READY=$(kubectl get nodes --no-headers | grep -v Ready | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
    echo "✅ All nodes are Ready"
else
    echo "⚠️  $NOT_READY node(s) not ready"
fi

# Display node information
echo ""
echo "📊 Cluster Node Summary:"
kubectl get nodes -o wide

# Mark step as complete
touch /root/cluster-setup/.step6-complete

echo ""
echo "🎉 Step 6 verification passed!"
echo "✅ Token management and worker join process understood"
echo ""
echo "💡 In production environments:"
echo "   - Ensure all worker nodes complete Steps 1-3 first"
echo "   - Generate join command: kubeadm token create --print-join-command"
echo "   - Run join command on each worker node"
echo "   - Verify with: kubectl get nodes"
echo ""
echo "Proceed to Step 7: Final Verification and Testing ➡️"
