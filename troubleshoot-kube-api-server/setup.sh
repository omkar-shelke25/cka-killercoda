#!/bin/bash
set -euo pipefail

echo "Setting up the broken kube-apiserver scenario..."

# Wait for the cluster to be initially ready
sleep 10

# Backup the original kube-apiserver manifest
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.backup

# Modify the kube-apiserver manifest to have excessive CPU requests (4000m when node has only 1000m)
# This will cause the kubelet to fail to schedule the Pod
sudo sed -i 's/cpu: 50m/cpu: 4000m/' /etc/kubernetes/manifests/kube-apiserver.yaml

 sudo systemctl restart kubelet.service 

# Wait a bit for kubelet to detect the change
sleep 5

echo ""
echo "⚠️  Setup complete: kube-apiserver has been misconfigured with CPU requests of 4000m"
echo "⚠️  The node only has 1000m total CPU capacity"
echo ""
echo "🔍 The kube-apiserver Pod should now be failing to start..."
echo ""
echo "Check the issue with:"
echo "  kubectl get pods -n kube-system | grep apiserver"
echo "  crictl ps -a | grep apiserver"
echo ""
