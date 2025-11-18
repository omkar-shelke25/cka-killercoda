#!/bin/bash
set -euo pipefail

# Debugging: print commands (optional — comment out if noisy)
# set -x

echo "📊 Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update

# Ensure kube-system exists (should already)
kubectl get ns kube-system >/dev/null 2>&1 || kubectl create ns kube-system

# Install metrics-server (ignore error if already installed)
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\,Hostname\,InternalDNS\,ExternalDNS,--metric-resolution=15s}" \
  --wait || true

sleep 5

# Create namespace (idempotent)
kubectl create ns jujutsu-high >/dev/null 2>&1 || true

# Create directory (handle space in name)
DEP_DIR="/Jujutsu Kaisen"
DEP_FILE="${DEP_DIR}/jujutsu-kaisen-deployment.yaml"

mkdir -p "$DEP_DIR"

# Write the deployment manifest to disk (use quotes so spaces are safe)
cat > "$DEP_FILE" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tokyo-jutsu
  namespace: jujutsu-high
  labels:
    environment: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tokyo-jutsu
      environment: production
  template:
    metadata:
      labels:
        app: tokyo-jutsu
        environment: production
    spec:
      containers:
        - name: app
          image: nginx
          ports:
            - containerPort: 80
EOF

# Verify file was written and show it (helpful for debugging)
if [ -f "$DEP_FILE" ]; then
  echo "✅ Deployment manifest written to: $DEP_FILE"
  echo "---- file contents ----"
  sed -n '1,200p' "$DEP_FILE"
  echo "-----------------------"
else
  echo "❌ Failed to write deployment manifest to $DEP_FILE" >&2
  exit 1
fi

# Create the Service (applies directly)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: tokyo-jutsu-svc
  namespace: jujutsu-high
  labels:
    environment: production
spec:
  type: ClusterIP
  selector:
    app: tokyo-jutsu
    environment: production
  ports:
    - port: 80
      targetPort: 80
EOF

# Create the HPA
kubectl apply -f - <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gojo-hpa
  namespace: jujutsu-high
  labels:
    environment: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tokyo-jutsu
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: AverageValue
          averageValue: 512m
    - type: Resource
      resource:
        name: memory
        target:
          type: AverageValue
          averageValue: 512Mi
EOF

# Apply the Deployment from the stored file (quotes protect space in path)
kubectl apply -f "$DEP_FILE"

sleep 2

echo "✅ Setup complete — deployment applied from $DEP_FILE"
echo "Run: kubectl -n jujutsu-high get pods,deployment,svc,hpa"
