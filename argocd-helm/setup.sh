#!/bin/bash
set -euo pipefail

# Create argocd namespace
echo ""
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD CRDs (simulating that platform team has already installed them)
echo ""
echo "Installing Argo CD CRDs (simulating platform team installation)..."
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/crds/application-crd.yaml 2>/dev/null || echo "CRDs already exist or installation skipped"
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/crds/applicationset-crd.yaml 2>/dev/null || echo "CRDs already exist or installation skipped"
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/crds/appproject-crd.yaml 2>/dev/null || echo "CRDs already exist or installation skipped"

# Verify CRDs are installed
echo ""
echo "Verifying Argo CD CRDs are installed..."
sleep 5

CRD_COUNT=$(kubectl get crd 2>/dev/null | grep -c "argoproj.io" || echo "0")

if [[ ${CRD_COUNT} -gt 0 ]]; then
    echo "✅ Found ${CRD_COUNT} Argo CD CRD(s) in the cluster:"
    kubectl get crd | grep "argoproj.io" || true
else
    echo "⚠️  No Argo CD CRDs found (this is okay for the exercise)"
fi
