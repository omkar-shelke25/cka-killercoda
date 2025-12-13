#!/bin/bash
set -euo pipefail

echo "Setting up Helm and Kubernetes environment..."
echo ""




# Create argocd namespace (but don't install anything yet)
echo ""
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

