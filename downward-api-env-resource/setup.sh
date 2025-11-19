#!/bin/bash
set -euo pipefail

# Create namespace
kubectl create namespace react-frontend

# Create directory for manifest files
mkdir -p /app

# Create ConfigMap with monitoring script
cat > /app/monitor-configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitor-agent-cm
  namespace: react-frontend
data:
  monitor.sh: |
    #!/bin/sh
    echo "========================================"
    echo " 🚀 React Frontend Resource Monitor"
    echo "========================================"
    echo " ⚙️  CPU Request  : ${APP_CPU_REQUEST}m"
    echo " ⚙️  CPU Limit    : ${APP_CPU_LIMIT}m"
    echo " 🧠 Mem Request: ${APP_MEM_REQUEST}Mi"
    echo " 🧠 Mem Limit  : ${APP_MEM_LIMIT}Mi"
    echo "----------------------------------------"
    while true; do
      TS=`date -Is`
      echo "$TS  ⚙️ CPU_REQ=${APP_CPU_REQUEST}m | CPU_LIM=${APP_CPU_LIMIT}m | 🧩 MEM_REQ=${APP_MEM_REQUEST}Mi | MEM_LIM=${APP_MEM_LIMIT}Mi"
      sleep 15
    done
EOF

# Apply ConfigMap
kubectl apply -f /app/monitor-configmap.yaml

# Create initial Pod without Downward API environment variables
cat > /app/react-ui.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: react-frontend-monitor
  namespace: react-frontend
  labels:
    app.kubernetes.io/name: react-frontend
    tier: frontend
spec:
  containers:
  - name: frontend-app
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
  - name: monitor-agent
    image: busybox:1.36
    command: ["/bin/sh", "/opt/monitor/monitor.sh"]
    volumeMounts:
      - name: monitor-script
        mountPath: /opt/monitor
        readOnly: true
  volumes:
    - name: monitor-script
      configMap:
        name: monitor-agent-cm
        defaultMode: 0755
EOF

# Apply Pod manifest
kubectl apply -f /app/react-ui.yaml

# Wait for resources to be created
sleep 3

echo "✅ Setup completed successfully!"
echo "📂 ConfigMap manifest: /app/monitor-configmap.yaml"
echo "📂 Pod manifest: /app/react-ui.yaml"
echo ""
echo "🔍 To inspect the monitoring script:"
echo "   kubectl exec -n react-frontend react-frontend-monitor -c monitor-agent -- cat /opt/monitor/monitor.sh"
