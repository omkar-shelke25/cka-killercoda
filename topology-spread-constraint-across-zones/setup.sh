#!/bin/bash
set -euo pipefail

kubectl taint no controlplane node-role.kubernetes.io/control-plane:NoSchedule-

sleep 5

kubectl label node controlplane traveljp.io/deployment-domain=tokyo-a-server
kubectl label node node01 traveljp.io/deployment-domain=tokyo-b-server

kubectl create ns japan-tourism-platform

# Create directory structure
mkdir -p /japan-travel-application

# Create the deployment YAML file
cat > /japan-travel-application/japan-tourism.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/part-of: travel-japan-platform
    team.owner: travel-platform
    workload.type: stateless
  name: travel-jp-recommender
  namespace: japan-tourism-platform
spec:
  replicas: 7
  selector:
    matchLabels:
      app.kubernetes.io/component: frontend
      app.kubernetes.io/version: v1.0.0
  strategy: {}
  template:
    metadata:
      labels:
        app.kubernetes.io/component: frontend
        app.kubernetes.io/version: v1.0.0
    spec:
      containers:
      - image: public.ecr.aws/nginx/nginx:mainline-trixie
        name: backend
        ports:
        - containerPort: 80
        resources: {}
status: {}
EOF
