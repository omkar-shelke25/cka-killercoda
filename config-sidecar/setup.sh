#!/bin/bash
set -euo pipefail

echo "🚀 Setting up sidecar container lab environment..."

# Create production namespace
kubectl create namespace production

# Create a simple web application deployment that generates logs
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        tier: frontend
    spec:
      containers:
      - name: application
        image: busybox:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          mkdir -p /var/log/app
          echo "Application starting..." > /var/log/app/app.log
          while true; do
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Processing request \$RANDOM" >> /var/log/app/app.log
            sleep 5
          done
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/app
      volumes:
      - name: log-volume
        emptyDir: {}
EOF

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/web-app -n production --timeout=120s

# Create a service for the application
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: production
spec:
  selector:
    app: web-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Deployed resources:"
echo ""
echo "Production namespace:"
kubectl get deployments,pods,svc -n production
echo ""
echo "Current deployment configuration:"
kubectl get deployment web-app -n production -o yaml | grep -A 20 "spec:" | head -30
echo ""
echo "🎯 Your task: Add a sidecar container to the web-app deployment"
echo "   Requirements:"
echo "   - Add sidecar container named 'log-agent'"
echo "   - Use image: fluentd:latest"
echo "   - Share /var/log/app volume between containers"
echo "   - Sidecar must mount volume at /var/log/app"
echo "   - Do not modify the existing application container"
echo "   - Do not change labels, selectors, or replica count"
echo "   - Let Fluentd run with its default configuration"
echo ""
