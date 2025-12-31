#!/bin/bash
set -euo pipefail

echo "Setting up DaemonSet scenario..."

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# Show node information
echo ""
echo "Cluster nodes:"
kubectl get nodes -o wide

echo ""
echo "Setup complete!"
echo ""
echo "Your task: Create a DaemonSet named 'ds-important' in namespace 'project-tiger'"
echo "that runs on ALL nodes including control plane nodes."
echo ""
