#!/bin/bash
set -euo pipefail


# Install metrics-server
echo "📊 Installing metrics-server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP\,Hostname\,InternalDNS\,ExternalDNS,--metric-resolution=15s}" \
  --wait

sleep 5


# Create namespace
kubectl create ns jujutsu-high

# Create directory structure
mkdir -p "/Jujutsu Kaisen"

# Create the deployment YAML file
cat > "/Jujutsu Kaisen/jujutsu-kaisen-deployment.yaml" <<'EOF'
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

# Create the Service
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

kubectl apply -f /Jujutsu Kaisen/jujutsu-kaisen-deployment.yaml -n jujutsu-high

sleep 5

echo "Setup complete!"
