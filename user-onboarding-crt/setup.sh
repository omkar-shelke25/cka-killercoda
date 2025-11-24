#!/bin/bash
set -euo pipefail

echo "🎮 Setting up GameForge Studios Kubernetes environment..."

# Create the game-dev namespace
kubectl create namespace game-dev

# Deploy some sample resources for testing
kubectl create deployment mecha-pulse-api \
  --image=nginx:alpine \
  --replicas=2 \
  -n game-dev

kubectl create deployment mecha-pulse-frontend \
  --image=nginx:alpine \
  --replicas=1 \
  -n game-dev

# Wait for deployments to be ready
kubectl wait --for=condition=available deployment/mecha-pulse-api -n game-dev --timeout=60s
kubectl wait --for=condition=available deployment/mecha-pulse-frontend -n game-dev --timeout=60s

# Create a service for testing
kubectl expose deployment mecha-pulse-api \
  --port=80 \
  --target-port=80 \
  --name=mecha-api-service \
  -n game-dev

# Rename the default cluster to match the scenario
kubectl config rename-context kubernetes-admin@kubernetes mecha-pulse-game-dev

# Create directory for user certificates
mkdir -p /etc/kubernetes/pki/users
mkdir -p /root/gameforge-onboarding

# Create a README file with CA location info
cat > /root/gameforge-onboarding/README.txt << 'EOF'
GameForge Studios - Kubernetes User Onboarding
===============================================

Important Information:
- Kubernetes CA certificate: /etc/kubernetes/pki/ca.crt
- Kubernetes CA key: /etc/kubernetes/pki/ca.key
- Target namespace: game-dev
- New user: siddhi.shelke01
- Organization: gameforge-studios

Working directory: /root/gameforge-onboarding/

Sample resources deployed in game-dev namespace:
- Deployment: mecha-pulse-api (2 replicas)
- Deployment: mecha-pulse-frontend (1 replica)
- Service: mecha-api-service

Your task: Complete the full user onboarding workflow!
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📁 Working directory: /root/gameforge-onboarding/"
echo "🎯 Target namespace: game-dev"
echo "👤 New user: siddhi.shelke01"
echo ""
echo "Ready to begin user onboarding! 🚀"
