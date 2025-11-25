#!/bin/bash
set -euo pipefail

# Create the internal directory for storing manifests
mkdir -p /internal

# Install OpenEBS using Helm
echo "📦 Installing OpenEBS..."

# Add OpenEBS Helm repository
helm repo add openebs https://openebs.github.io/charts 2>/dev/null || true
helm repo update

# Install OpenEBS in the openebs namespace
helm install openebs --namespace openebs openebs/openebs --create-namespace --wait --timeout=5m

echo "⏳ Waiting for OpenEBS components to be ready..."
sleep 10

# Wait for OpenEBS local provisioner to be ready
kubectl wait --for=condition=available --timeout=120s deployment/openebs-localpv-provisioner -n openebs 2>/dev/null || true

