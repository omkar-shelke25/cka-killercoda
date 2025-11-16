#!/bin/bash
set -euo pipefail

# Apply taint to node01 only
kubectl taint node node01 node-role.kubernetes.io/mcp=true:NoSchedule

# Label node01
kubectl label node node01 node-role.kubernetes.io/mcp=true

# Create namespace with labels
kubectl create ns mcp-inference
kubectl label namespace mcp-inference environment=production ai.team=ml-engineering

sleep 5

# Create directory structure
mkdir -p /test-api-backed/teams

# Create the deployment YAML file without tolerations
cat > /test-api-backed/teams/mcp-inference.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-postman
  namespace: mcp-inference
  labels:
    app.kubernetes.io/name: mcp-postman
    app.kubernetes.io/component: mcp-test-runner
spec:
  replicas: 4
  selector:
    matchLabels:
      ai.model/type: llm
      ai.model/name: mcp  
  template:
    metadata:
      labels:
        ai.model/type: llm
        ai.model/name: mcp        
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/mcp
                operator: Exists
      containers:
        - name: mcp-postman
          image: nginx:alpine
          command: ["sh", "-c", "while true; do sleep 3600; done"]
EOF

# Apply the deployment (it will have pending pods)
kubectl apply -f /test-api-backed/teams/mcp-inference.yaml

echo "Setup complete. The mcp-postman deployment has been created without tolerations - pods will be pending."
