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

# Rename the default context to match the scenario
kubectl config rename-context kubernetes-admin@kubernetes mecha-pulse-game-dev 2>/dev/null || true


mkdir -p /root/gameforge-onboarding

