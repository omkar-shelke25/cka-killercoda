#!/bin/bash
set -euo pipefail

# Create the gitlab-cicd namespace
kubectl create ns gitlab-cicd

# Create the ServiceAccount
kubectl create sa gitlab-cicd-sa -n gitlab-cicd

# Create a simple nginx pod for testing
kubectl run gitlab-cicd-nginx \
  --image=nginx:alpine \
  --namespace=gitlab-cicd \
  --labels="app=gitlab-cicd,component=test-pod"

# Wait for the pod to be running
kubectl wait --for=condition=ready pod/gitlab-cicd-nginx -n gitlab-cicd --timeout=60s

# Create directory structure for storing outputs
mkdir -p /gitlab-cicd

echo "Setup complete: namespace gitlab-cicd, ServiceAccount gitlab-cicd-sa, and pod gitlab-cicd-nginx created."
