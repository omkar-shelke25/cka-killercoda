#!/bin/bash
set -euo pipefail

echo "Setting up cert-manager environment..."

# Wait for cluster to be ready
kubectl wait --for=condition=ready node --all --timeout=120s

# Install cert-manager using kubectl
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager namespace to be created
echo "Waiting for cert-manager namespace..."
while ! kubectl get namespace cert-manager &>/dev/null; do
  sleep 2
done

# Wait for cert-manager CRDs to be installed
echo "Waiting for cert-manager CRDs to be registered..."
sleep 10

# List of expected CRDs
EXPECTED_CRDS=(
  "certificates.cert-manager.io"
  "certificaterequests.cert-manager.io"
  "issuers.cert-manager.io"
  "clusterissuers.cert-manager.io"
  "challenges.acme.cert-manager.io"
  "orders.acme.cert-manager.io"
)

# Wait for all CRDs to be available
for crd in "${EXPECTED_CRDS[@]}"; do
  echo "Checking for CRD: ${crd}"
  while ! kubectl get crd "${crd}" &>/dev/null; do
    echo "  Waiting for ${crd}..."
    sleep 3
  done
  echo "  ✓ ${crd} is available"
done

# Wait for cert-manager pods to be ready
echo ""
echo "Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=180s
kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=180s
kubectl wait --for=condition=available deployment/cert-manager-cainjector -n cert-manager --timeout=180s

# Verify installation
echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 cert-manager components:"
kubectl get pods -n cert-manager
echo ""
echo "📋 cert-manager CRDs installed:"
kubectl get crd | grep cert-manager
echo ""
echo "🎯 Your task: Explore and document cert-manager CRDs"
echo ""
