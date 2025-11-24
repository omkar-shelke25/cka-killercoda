#!/bin/bash

set -e

echo "🔍 Verifying kube-apiserver recovery..."

CERT_DIR="/etc/kubernetes/pki"
KEY="$CERT_DIR/apiserver.key"
CRT="$CERT_DIR/apiserver.crt"

echo "---------------------------------"
echo "📝 Checking regenerated certificates..."
if [[ -f "$KEY" && -f "$CRT" ]]; then
    echo "✅ Certificates exist: apiserver.key & apiserver.crt"
else
    echo "❌ Missing API server certificates!"
    exit 1
fi

echo "---------------------------------"
echo "🔧 Checking kubelet service..."
if systemctl is-active --quiet kubelet; then
    echo "✅ kubelet is running"
else
    echo "❌ kubelet is NOT running"
    exit 1
fi

echo "---------------------------------"
echo "📦 Checking kube-apiserver container..."
if sudo crictl ps | grep -q kube-apiserver; then
    echo "✅ kube-apiserver container is running"
else
    echo "❌ kube-apiserver container NOT running"
    sudo crictl ps -a | grep kube-apiserver
    exit 1
fi

echo "---------------------------------"
echo "📊 Checking Kubernetes API..."
if kubectl get pods -A &>/dev/null; then
    echo "✅ Kubernetes API is operational"
else
    echo "❌ Kubernetes API not responding"
    exit 1
fi

echo "---------------------------------"
echo "🎉 ALL CHECKS PASSED — kube-apiserver recovery successful"
