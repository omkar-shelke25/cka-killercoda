#!/bin/bash
set -euo pipefail

# Label nodes with zone topology
kubectl label node controlplane nara.io/zone=zone-a
kubectl label node node01 nara.io/zone=zone-b

# Remove taint from controlplane to allow scheduling
kubectl taint no controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Wait for cluster to stabilize
sleep 7

# Create namespace
kubectl create ns nara

# Create the frontend deployment (already running)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nara-frontend
  namespace: nara
  labels:
    app: nara-frontend
    tier: frontend
    project: nara
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nara-frontend
  template:
    metadata:
      labels:
        app: nara-frontend
        tier: frontend
        project: nara
    spec:
      nodeName: controlplane
      containers:
        - name: frontend
          image: nginx:stable
          ports:
            - containerPort: 80
EOF

# Create directory structure
mkdir -p /nara.io

# Create the backend manifest WITHOUT PodAffinity (student needs to add it)
cat <<'EOF' > /nara.io/nara-backend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nara-backend
  namespace: nara
  labels:
    app: nara-backend
    tier: backend
    project: nara
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nara-backend
  template:
    metadata:
      labels:
        app: nara-backend
        tier: backend
        project: nara
    spec:
      containers:
        - name: backend
          image: node:alpine
          command: ["sh", "-c", "tail -f /dev/null"]
          ports:
            - containerPort: 3000
EOF

echo "✅ Setup complete! Frontend is running, backend manifest is ready at /nara.io/nara-backend.yaml"
