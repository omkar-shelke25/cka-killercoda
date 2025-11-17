#!/bin/bash
set -euo pipefail

# Install metrics-server using Helm
echo "📊 Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ > /dev/null 2>&1
helm repo update > /dev/null 2>&1
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system --create-namespace \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\,Hostname\,InternalDNS\,ExternalDNS,--metric-resolution=15s}" \
  > /dev/null 2>&1

# Wait for metrics-server to be ready
echo "⏳ Waiting for metrics-server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=metrics-server -n kube-system --timeout=120s > /dev/null 2>&1

# Create namespace
kubectl create ns isro-jaxa

# Create directory structure
mkdir -p /isro-jaxa

# Create the deployment and service YAML
cat > /tmp/isro-jaxa-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: isro-jaxa-collab-deployment
  namespace: isro-jaxa
  labels:
    app: isro-jaxa-app
    collaboration: isro-jaxa
    countries: india-japan
spec:
  replicas: 1
  selector:
    matchLabels:
      app: isro-jaxa-app
  template:
    metadata:
      labels:
        app: isro-jaxa-app
        collaboration: isro-jaxa
        countries: india-japan
    spec:
      containers:
      - name: isro-jaxa-container
        image: nginx
        resources:
          requests:
            cpu: 200m
            memory: 200Mi
          limits:
            cpu: 200m
            memory: 200Mi
---
apiVersion: v1
kind: Service
metadata:
  name: isro-jaxa-collab-service
  namespace: isro-jaxa
  labels:
    app: isro-jaxa-app
    collaboration: isro-jaxa
    countries: india-japan
spec:
  selector:
    app: isro-jaxa-app
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
EOF

# Apply the deployment and service
kubectl apply -f /tmp/isro-jaxa-deployment.yaml > /dev/null 2>&1

# Wait for deployment to be ready
kubectl wait --for=condition=available deployment/isro-jaxa-collab-deployment -n isro-jaxa --timeout=120s > /dev/null 2>&1

# Create the load generator pod
cat > /tmp/lunar-robot.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: lunar-robot-01
  namespace: isro-jaxa
  labels:
    app: lunar-robot
spec:
  containers:
  - name: ab
    image: jordi/ab
    command: ["sh", "-c"]
    args:
      - |
        # Wait for service to be available
        sleep 10
        # loop forever: run ab, wait a bit, repeat
        while true; do
          # -n = total requests per run, -c = concurrency
          ab -n 7500 -c 20 http://isro-jaxa-collab-service.isro-jaxa.svc.cluster.local/ >/dev/null 2>&1
          sleep 2
        done
    resources:
      requests:
        cpu: "200m"
        memory: "200Mi"
      limits:
        cpu: "512m"
        memory: "512Mi"
  restartPolicy: Always
EOF

# Apply the load generator
kubectl apply -f /tmp/lunar-robot.yaml > /dev/null 2>&1

# Wait for load generator pod to be ready
kubectl wait --for=condition=ready pod/lunar-robot-01 -n isro-jaxa --timeout=120s > /dev/null 2>&1

# Wait a bit for metrics to start being collected
sleep 10

echo "✅ Setup complete! ISRO-JAXA environment is ready."
