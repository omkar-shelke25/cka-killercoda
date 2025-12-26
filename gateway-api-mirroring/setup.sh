#!/bin/bash
set -euo pipefail


# Install MetalLB for LoadBalancer support
echo "🔧 Installing MetalLB for LoadBalancer support..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml > /dev/null 2>&1

echo "⏳ Waiting for MetalLB to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=component=controller \
  --timeout=120s > /dev/null 2>&1 || echo "Waiting for MetalLB..."

sleep 5

echo "🌐 Configuring MetalLB IP Address Pool..."
cat <<'YAML' | kubectl apply -f - > /dev/null 2>&1
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-address-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-address-pool
YAML

sleep 5

echo "🎌 Setting up Anime Streaming Platform..."

echo "192.168.1.240 anime.streaming.io" | sudo tee -a /etc/hosts

# Install Gateway API CRDs
echo "📦 Installing Kubernetes Gateway API CRDs..."
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.3.0" | kubectl apply -f - > /dev/null 2>&1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f - > /dev/null 2>&1

# Install NGINX Gateway Fabric
echo "🔌 Installing NGINX Gateway Fabric..."
helm repo add nginx-stable https://helm.nginx.com/stable > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n gateway --wait > /dev/null 2>&1



# Create prod namespace
echo "🏗️ Creating prod namespace..."
kubectl create namespace prod > /dev/null 2>&1 || true

# Create ConfigMap for api-v1
echo "📝 Creating ConfigMap for api-v1..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-v1-code
  namespace: prod
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "api_version": "v1",
      "version_emoji": "🟢",
      "service": "Anime Stream Pro API",
      "status": "stable",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Production API serving anime recommendations",
      "recommendations": [
        {
          "id": 1,
          "title": "Attack on Titan",
          "emoji": "⚔️",
          "genre": "Action, Dark Fantasy",
          "rating": 9.0,
          "episodes": 87,
          "status": "Completed"
        },
        {
          "id": 2,
          "title": "My Hero Academia",
          "emoji": "🦸",
          "genre": "Superhero, Action",
          "rating": 8.4,
          "episodes": 138,
          "status": "Ongoing"
        },
        {
          "id": 3,
          "title": "Demon Slayer",
          "emoji": "🗡️",
          "genre": "Action, Historical",
          "rating": 8.7,
          "episodes": 55,
          "status": "Ongoing"
        },
        {
          "id": 4,
          "title": "One Piece",
          "emoji": "🏴‍☠️",
          "genre": "Adventure, Comedy",
          "rating": 8.9,
          "episodes": 1085,
          "status": "Ongoing"
        },
        {
          "id": 5,
          "title": "Death Note",
          "emoji": "📓",
          "genre": "Psychological, Thriller",
          "rating": 9.0,
          "episodes": 37,
          "status": "Completed"
        }
      ],
      "stats": {
        "total_anime": 15000,
        "active_users": 2500000,
        "requests_today": 4523891
      }
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        # Log request to stdout
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 🟢 API-V1 - Request received: {s.path} from {s.client_address[0]}", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-API-Version", "v1")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 🟢 API-V1 - Response sent: 200 OK", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("🟢 API v1 starting on port 8080...", flush=True)
      print("🟢 Ready to serve anime recommendations (Production)", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
EOF

# Create ConfigMap for api-v2
echo "📝 Creating ConfigMap for api-v2..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-v2-code
  namespace: prod
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "api_version": "v2",
      "version_emoji": "🔵",
      "service": "Anime Stream Pro API - Next Gen",
      "status": "testing",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "New API with enhanced ML-based recommendations",
      "new_features": [
        "🤖 AI-powered personalization",
        "⚡ 40% faster response time",
        "🎯 Better genre matching",
        "🌟 User similarity scoring"
      ],
      "recommendations": [
        {
          "id": 1,
          "title": "Jujutsu Kaisen",
          "emoji": "👊",
          "genre": "Action, Supernatural",
          "rating": 8.6,
          "episodes": 47,
          "status": "Ongoing",
          "match_score": 95,
          "reason": "High action scenes match your preference"
        },
        {
          "id": 2,
          "title": "Spy x Family",
          "emoji": "🕵️",
          "genre": "Comedy, Action",
          "rating": 8.7,
          "episodes": 37,
          "status": "Ongoing",
          "match_score": 92,
          "reason": "Blend of action and wholesome moments"
        },
        {
          "id": 3,
          "title": "Chainsaw Man",
          "emoji": "🪚",
          "genre": "Action, Dark Fantasy",
          "rating": 8.5,
          "episodes": 12,
          "status": "Ongoing",
          "match_score": 89,
          "reason": "Dark themes similar to your watch history"
        },
        {
          "id": 4,
          "title": "Mob Psycho 100",
          "emoji": "💫",
          "genre": "Action, Comedy",
          "rating": 8.5,
          "episodes": 37,
          "status": "Completed",
          "match_score": 87,
          "reason": "Unique animation style you might enjoy"
        },
        {
          "id": 5,
          "title": "Vinland Saga",
          "emoji": "⚓",
          "genre": "Action, Historical",
          "rating": 8.8,
          "episodes": 48,
          "status": "Ongoing",
          "match_score": 91,
          "reason": "Epic storytelling matches your taste"
        }
      ],
      "ml_insights": {
        "user_cluster": "action-enthusiast",
        "predicted_genres": ["Action", "Dark Fantasy", "Thriller"],
        "confidence": 0.94
      },
      "stats": {
        "total_anime": 15000,
        "active_users": 2500000,
        "requests_today": 125430,
        "ml_accuracy": "94.2%"
      }
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        # Log request to stdout
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 🔵 API-V2 - MIRRORED Request received: {s.path} from {s.client_address[0]}", flush=True)
        print(f"[{timestamp}] 🔵 API-V2 - Processing with ML engine...", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-API-Version", "v2")
        s.send_header("X-ML-Enabled", "true")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 🔵 API-V2 - Response generated (will be discarded by Gateway)", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("🔵 API v2 starting on port 8080...", flush=True)
      print("🔵 Ready for traffic mirroring tests (ML-Enhanced)", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
EOF

# Deploy api-v1 (stable anime API)
echo "🎬 Deploying api-v1 (stable)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v1
  namespace: prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      version: v1
  template:
    metadata:
      labels:
        app: api
        version: v1
    spec:
      containers:
      - name: api
        image: python:3.11-slim
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        command: ["python", "-u", "/app/server.py"]
        volumeMounts:
        - name: code
          mountPath: /app
      volumes:
      - name: code
        configMap:
          name: api-v1-code
---
apiVersion: v1
kind: Service
metadata:
  name: api-v1
  namespace: prod
spec:
  type: ClusterIP
  selector:
    app: api
    version: v1
  ports:
  - port: 80
    targetPort: 8080
EOF

# Deploy api-v2 (new anime API)
echo "🚀 Deploying api-v2 (new version)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v2
  namespace: prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      version: v2
  template:
    metadata:
      labels:
        app: api
        version: v2
    spec:
      containers:
      - name: api
        image: python:3.11-slim
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        command: ["python", "-u", "/app/server.py"]
        volumeMounts:
        - name: code
          mountPath: /app
      volumes:
      - name: code
        configMap:
          name: api-v2-code
---
apiVersion: v1
kind: Service
metadata:
  name: api-v2
  namespace: prod
spec:
  type: ClusterIP
  selector:
    app: api
    version: v2
  ports:
  - port: 80
    targetPort: 8080
EOF

# Create anime-gtw namespace
echo "🏗️ Creating anime-gtw namespace..."
kubectl create namespace anime-gtw > /dev/null 2>&1 || true

# Create Gateway
echo "🌉 Creating Gateway..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: anime-app-gateway
  namespace: anime-gtw
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: anime.streaming.io
    allowedRoutes:
      namespaces: 
        from: Selector
        selector: 
          matchLabels:
            kubernetes.io/metadata.name: prod
EOF

# Wait for deployments
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/api-v1 -n prod --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/api-v2 -n prod --timeout=120s > /dev/null 2>&1

echo ""
echo "✅ Setup complete! Anime Streaming Platform is ready."
echo ""
echo "📋 Environment Overview:"
echo "   • Gateway Namespace: anime-gtw"
echo "   • Application Namespace: prod"
echo "   • Services: api-v1 (stable), api-v2 (testing)"
echo "   • Gateway: anime-app-gateway (anime-gtw)"
echo "   • ConfigMaps: api-v1-code, api-v2-code (mounted at /app)"
echo ""
echo "🎯 Your task: Create HTTPRoute with traffic mirroring"
echo "   • Primary backend: api-v1 (users get responses from here)"
echo "   • Mirror target: api-v2 (10% of traffic copied here for testing)"
echo "   • Save manifest to: /root/api-route.yaml"
echo ""
echo "📊 Monitor logs with:"
echo "   kubectl logs -f deployment/api-v1 -n prod"
echo "   kubectl logs -f deployment/api-v2 -n prod"
