#!/bin/bash
set -e

echo "🔍 Verifying Step 5: CNI Plugin Installation..."
echo ""

# Check if node is Ready
echo "Checking node status..."
NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}' | head -1)
if [ "$NODE_STATUS" == "Ready" ]; then
    echo "✅ Master node is Ready"
else
    echo "❌ Master node is not Ready (status: $NODE_STATUS)"
    echo "   CNI plugin may not be installed correctly"
    exit 1
fi

# Check for CNI pods (Calico or Flannel)
echo "Checking for CNI plugin..."
CNI_FOUND=false

# Check for Calico
if kubectl get ns calico-system &> /dev/null; then
    echo "Detected Calico CNI"
    CALICO_PODS=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l)
    CALICO_RUNNING=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ "$CALICO_PODS" -gt 0 ]; then
        echo "✅ Calico is installed ($CALICO_RUNNING/$CALICO_PODS pods running)"
        CNI_FOUND=true
        
        if [ "$CALICO_RUNNING" -lt "$CALICO_PODS" ]; then
            echo "⚠️  Not all Calico pods are running yet"
        fi
    fi
fi

# Check for Flannel
if kubectl get ns kube-flannel &> /dev/null; then
    echo "Detected Flannel CNI"
    FLANNEL_PODS=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | wc -l)
    FLANNEL_RUNNING=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | grep Running | wc -l)
    
    if [ "$FLANNEL_PODS" -gt 0 ]; then
        echo "✅ Flannel is installed ($FLANNEL_RUNNING/$FLANNEL_PODS pods running)"
        CNI_FOUND=true
        
        if [ "$FLANNEL_RUNNING" -lt "$FLANNEL_PODS" ]; then
            echo "⚠️  Not all Flannel pods are running yet"
        fi
    fi
fi

if [ "$CNI_FOUND" = false ]; then
    echo "❌ No CNI plugin detected (neither Calico nor Flannel)"
    echo "   Install a CNI plugin to enable networking"
    exit 1
fi

# Check CoreDNS pods
echo "Checking CoreDNS..."
COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep Running | wc -l)

if [ "$COREDNS_PODS" -ge 2 ]; then
    echo "✅ CoreDNS is present ($COREDNS_RUNNING/$COREDNS_PODS pods running)"
else
    echo "❌ CoreDNS pods not found"
    exit 1
fi

# Check kube-proxy
echo "Checking kube-proxy..."
KUBEPROXY_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers 2>/dev/null | wc -l)
if [ "$KUBEPROXY_PODS" -ge 1 ]; then
    echo "✅ kube-proxy is running"
else
    echo "❌ kube-proxy not found"
    exit 1
fi

# Check control plane pods
echo "Checking control plane health..."
CONTROL_PLANE_RUNNING=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$CONTROL_PLANE_RUNNING" -ge 3 ]; then
    echo "✅ Control plane components are healthy"
else
    echo "⚠️  Some control plane components may not be running"
fi

# Mark step as complete
touch /root/cluster-setup/.step5-complete

echo ""
echo "🎉 Step 5 verification passed!"
echo "✅ CNI plugin is installed and node is Ready"
echo "✅ Core cluster components are running"
echo ""
echo "Proceed to Step 6: Join Worker Nodes ➡️"
echo ""
echo "💡 In this environment, we have a single-node setup."
echo "   Step 6 will show you how to join worker nodes in multi-node clusters."
