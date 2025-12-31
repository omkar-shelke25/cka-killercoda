#!/bin/bash
set -euo pipefail

echo "Setting up NetworkPolicy scenario..."

# Create namespace
kubectl create ns project-snake

sleep 2

# Create backend Pods
for i in 0 1; do
  kubectl run backend-$i \
    --image=nginx:alpine \
    --labels="app=backend" \
    --namespace=project-snake \
    --port=80 \
    --command -- sh -c "nginx -g 'daemon off;'"
done

sleep 2

# Create db1 Pods
for i in 0 1; do
  kubectl run db1-$i \
    --image=nginx:alpine \
    --labels="app=db1" \
    --namespace=project-snake \
    --port=1111 \
    --command -- sh -c "sed 's/listen       80;/listen       1111;/' /etc/nginx/conf.d/default.conf > /tmp/default.conf && cp /tmp/default.conf /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
done

sleep 2

# Create db2 Pods
for i in 0 1; do
  kubectl run db2-$i \
    --image=nginx:alpine \
    --labels="app=db2" \
    --namespace=project-snake \
    --port=2222 \
    --command -- sh -c "sed 's/listen       80;/listen       2222;/' /etc/nginx/conf.d/default.conf > /tmp/default.conf && cp /tmp/default.conf /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
done

sleep 2

# Create vault Pods
for i in 0 1; do
  kubectl run vault-$i \
    --image=nginx:alpine \
    --labels="app=vault" \
    --namespace=project-snake \
    --port=3333 \
    --command -- sh -c "sed 's/listen       80;/listen       3333;/' /etc/nginx/conf.d/default.conf > /tmp/default.conf && cp /tmp/default.conf /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
done

# Wait for all Pods to be ready
echo "Waiting for Pods to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n project-snake --timeout=60s
kubectl wait --for=condition=ready pod -l app=db1 -n project-snake --timeout=60s
kubectl wait --for=condition=ready pod -l app=db2 -n project-snake --timeout=60s
kubectl wait --for=condition=ready pod -l app=vault -n project-snake --timeout=60s

echo ""
echo "Setup complete!"
echo ""
echo "Pods created in namespace 'project-snake':"
kubectl get pods -n project-snake -o wide --show-labels
echo ""
echo "Currently, all backend Pods can access all other Pods without restrictions."
echo "Your task is to create a NetworkPolicy to restrict this access."
