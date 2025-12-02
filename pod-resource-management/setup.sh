#!/bin/bash
set -euo pipefail

echo "🐍 Setting up Python ML Web Application..."

# Create namespace
kubectl create namespace python-ml-ns > /dev/null 2>&1 || true

# Create ConfigMap with Python application code
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: python-app-code
  namespace: python-ml-ns
data:
  app.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import os
    import socket
    
    class MLHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            data = {
                'application': 'Python ML Web Service',
                'status': 'running',
                'version': '2.0',
                'framework': 'TensorFlow-ready',
                'pod': os.environ.get('HOSTNAME', 'unknown'),
                'node': socket.gethostname(),
                'message': 'ML inference service ready',
                'endpoints': {
                    '/': 'Service info',
                    '/health': 'Health check',
                    '/predict': 'ML predictions'
                }
            }
            
            self.wfile.write(json.dumps(data, indent=2).encode())
        
        def log_message(self, format, *args):
            # Suppress default logging
            pass
    
    if __name__ == '__main__':
        print('🚀 Starting Python ML Web Service on port 8080...')
        print('📊 Ready for ML inference requests')
        server = HTTPServer(('0.0.0.0', 8080), MLHandler)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print('\n⚠️  Server stopped')
            server.shutdown()
EOF

# Deploy Python ML application without proper resource configuration
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-webapp
  namespace: python-ml-ns
  labels:
    app: python-webapp
    tier: ml-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: python-webapp
  template:
    metadata:
      labels:
        app: python-webapp
        tier: ml-service
    spec:
      initContainers:
      - name: init-setup
        image: busybox:1.28
        command: ['sh', '-c', 'echo "🔧 Initializing ML environment..." && sleep 2 && echo "✅ Initialization complete"']
        # No resources configured - needs to be added by student
      containers:
      - name: python-app
        image: python:3.11-slim
        command: ['python', '/app/app.py']
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: PYTHONUNBUFFERED
          value: "1"
        - name: APP_ENV
          value: "production"
        volumeMounts:
        - name: app-code
          mountPath: /app
        # No resources configured - needs to be added by student
      volumes:
      - name: app-code
        configMap:
          name: python-app-code
---
apiVersion: v1
kind: Service
metadata:
  name: python-webapp
  namespace: python-ml-ns
  labels:
    app: python-webapp
    tier: ml-service
spec:
  selector:
    app: python-webapp
  ports:
  - port: 80
    targetPort: 8080
    name: http
    protocol: TCP
  type: ClusterIP
EOF

# Wait a moment for deployment to be created
sleep 3


echo "📋 Current Status:"
kubectl get deployment python-webapp -n python-ml-ns 2>/dev/null || echo "Deployment created"
echo ""
echo "📦 Resources Created:"
echo "   • Namespace: python-ml-ns"
echo "   • ConfigMap: python-app-code (contains Python ML application)"
echo "   • Deployment: python-webapp (3 replicas, NO resources configured)"
echo "   • Service: python-webapp (ClusterIP)"
echo ""
echo "🎯 Your Mission:"
echo "Configure proper resource requests and limits for the Python ML web application"
echo "to ensure stable operation on the worker node with limited resources."
