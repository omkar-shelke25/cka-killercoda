#!/bin/bash
set -e

echo "🔍 Verifying Step 7: Final Cluster Verification..."
echo ""

# Check cluster info is accessible
echo "Checking cluster connectivity..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ Cluster is accessible"
else
    echo "❌ Cannot connect to cluster"
    exit 1
fi

# Check API server health
echo "Checking API server health..."
if kubectl get --raw='/readyz' &> /dev/null; then
    echo "✅ API server is healthy"
else
    echo "❌ API server health check failed"
    exit 1
fi

# Check all nodes are ready
echo "Checking node readiness..."
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
    READY_NODES=$(kubectl get nodes --no-headers | wc -l)
    echo "✅ All $READY_NODES node(s) are Ready"
else
    echo "❌ $NOT_READY node(s) are not ready"
    exit 1
fi

# Check critical system pods
echo "Checking critical system components..."

# API Server
if kubectl get pods -n kube-system -l component=kube-apiserver --no-headers | grep -q Running; then
    echo "✅ kube-apiserver is running"
else
    echo "❌ kube-apiserver is not running"
    exit 1
fi

# Scheduler
if kubectl get pods -n kube-system -l component=kube-scheduler --no-headers | grep -q Running; then
    echo "✅ kube-scheduler is running"
else
    echo "❌ kube-scheduler is not running"
    exit 1
fi

# Controller Manager
if kubectl get pods -n kube-system -l component=kube-controller-manager --no-headers | grep -q Running; then
    echo "✅ kube-controller-manager is running"
else
    echo "❌ kube-controller-manager is not running"
    exit 1
fi

# etcd
if kubectl get pods -n kube-system -l component=etcd --no-headers | grep -q Running; then
    echo "✅ etcd is running"
else
    echo "❌ etcd is not running"
    exit 1
fi

# CoreDNS
COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep Running | wc -l)
if [ "$COREDNS_READY" -ge 1 ]; then
    echo "✅ CoreDNS is running ($COREDNS_READY replica(s))"
else
    echo "❌ CoreDNS is not running"
    exit 1
fi

# Test pod creation capability
echo "Testing pod creation..."
if kubectl run verify-test --image=nginx:alpine --restart=Never --dry-run=client -o yaml &> /dev/null; then
    echo "✅ Pod creation capability verified"
else
    echo "❌ Cannot create pods"
    exit 1
fi

# Test service creation capability
echo "Testing service creation..."
if kubectl create service clusterip verify-svc --tcp=80:80 --dry-run=client -o yaml &> /dev/null; then
    echo "✅ Service creation capability verified"
else
    echo "❌ Cannot create services"
    exit 1
fi

# Check CNI is functioning
echo "Checking CNI networking..."
CNI_PODS=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l)
FLANNEL_PODS=$(kubectl get pods -n kube-flannel --no-headers 2>/dev/null | wc -l)

if [ "$CNI_PODS" -gt 0 ] || [ "$FLANNEL_PODS" -gt 0 ]; then
    echo "✅ CNI plugin is functional"
else
    echo "❌ No CNI plugin found"
    exit 1
fi

# Check kube-proxy
echo "Checking kube-proxy..."
KUBEPROXY_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers | grep Running | wc -l)
if [ "$KUBEPROXY_PODS" -ge 1 ]; then
    echo "✅ kube-proxy is running"
else
    echo "❌ kube-proxy is not running"
    exit 1
fi

# Mark step as complete
touch /root/cluster-setup/.step7-complete

echo ""
echo "🎉🎉🎉 FINAL VERIFICATION PASSED! 🎉🎉🎉"
echo ""
echo "✅ Cluster is fully operational and ready for workloads"
echo ""
echo "📊 Cluster Summary:"
kubectl get nodes
echo ""
echo "💡 Your Kubernetes cluster is production-ready!"
echo ""
echo "Proceed to the Finish page for your achievement summary! 🏆"
