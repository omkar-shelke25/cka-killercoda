#!/bin/bash
set -euo pipefail

echo "🔬 Setting up Hawkins Lab - Stranger Things Streaming API..."

echo "192.168.1.240 api.stranger.things" | sudo tee -a /etc/hosts

# Install Gateway API CRDs
echo "📦 Installing Kubernetes Gateway API CRDs..."
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.3.0" | kubectl apply -f - > /dev/null 2>&1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v2.3.0" | kubectl apply -f - > /dev/null 2>&1

# Install NGINX Gateway Fabric
echo "⚡ Installing NGINX Gateway Fabric..."
helm repo add nginx-stable https://helm.nginx.com/stable > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n gateway --wait > /dev/null 2>&1

# Install MetalLB for LoadBalancer support
echo "🔧 Installing MetalLB for LoadBalancer support..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml > /dev/null 2>&1

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

# Create hawkins namespace
echo "🏗️ Creating hawkins namespace..."
kubectl create namespace hawkins > /dev/null 2>&1 || true

# Create ConfigMap for stv-v1 (stable version)
echo "📝 Creating ConfigMap for stv-v1 (stable)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: stv-v1-code
  namespace: hawkins
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "version": "v1",
      "mode": "normal",
      "version_emoji": "🟢",
      "service": "Stranger Things Streaming API",
      "status": "stable",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Welcome to Hawkins Streaming - Normal World",
      "trusted_by": "Eleven",
      "episodes": [
        {
          "season": 1,
          "episode": 1,
          "title": "The Vanishing of Will Byers",
          "emoji": "🚴",
          "rating": 8.9,
          "year": 2016,
          "runtime": "48 min"
        },
        {
          "season": 1,
          "episode": 8,
          "title": "The Upside Down",
          "emoji": "🌲",
          "rating": 9.1,
          "year": 2016,
          "runtime": "55 min"
        },
        {
          "season": 2,
          "episode": 9,
          "title": "The Gate",
          "emoji": "🔥",
          "rating": 9.3,
          "year": 2017,
          "runtime": "62 min"
        },
        {
          "season": 3,
          "episode": 8,
          "title": "The Battle of Starcourt",
          "emoji": "🎆",
          "rating": 9.4,
          "year": 2019,
          "runtime": "77 min"
        },
        {
          "season": 4,
          "episode": 9,
          "title": "The Piggyback",
          "emoji": "⚡",
          "rating": 9.5,
          "year": 2022,
          "runtime": "139 min"
        }
      ],
      "characters": [
        {"name": "Eleven", "emoji": "👧", "power": "Telekinesis", "status": "active"},
        {"name": "Mike Wheeler", "emoji": "🎮", "role": "Leader", "status": "active"},
        {"name": "Dustin Henderson", "emoji": "🎩", "trait": "Smart", "status": "active"},
        {"name": "Lucas Sinclair", "emoji": "🏹", "skill": "Wrist Rocket", "status": "active"},
        {"name": "Will Byers", "emoji": "🎨", "connection": "Upside Down", "status": "active"}
      ],
      "stats": {
        "total_episodes": 42,
        "total_seasons": 4,
        "active_viewers": 1500000,
        "hawkins_population": 30000
      }
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 🟢 STV-V1 (Stable) - Request: {s.path} from {s.client_address[0]}", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-API-Version", "v1")
        s.send_header("X-Mode", "normal")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 🟢 STV-V1 - Response sent: 200 OK (Normal World)", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("🟢 STV-V1 starting on port 8080...", flush=True)
      print("🟢 Stranger Things API v1 - Normal World Mode (Trusted by Eleven)", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
EOF

# Create ConfigMap for stv-v2 (upside down mode)
echo "📝 Creating ConfigMap for stv-v2 (experimental)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: stv-v2-code
  namespace: hawkins
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "version": "v2",
      "mode": "upside_down",
      "version_emoji": "🔴",
      "service": "Stranger Things Streaming API - UPSIDE DOWN MODE",
      "status": "experimental",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Welcome to the Upside Down - Experimental Features",
      "tested_by": "Dustin's Crew",
      "warning": "⚠️ You've entered the Upside Down dimension",
      "episodes": [
        {
          "season": 1,
          "episode": 1,
          "title": "sreʎꓭ llᴉM ɟo ƃuᴉɥsᴉuɐɅ ǝɥ⊥",
          "emoji": "🙃",
          "rating": 8.9,
          "year": 6102,
          "runtime": "niṃ 8Ꮞ",
          "dimension": "upside_down"
        },
        {
          "season": 1,
          "episode": 8,
          "title": "uʍoꓷ ǝpᴉsd∩ ǝɥ⊥",
          "emoji": "🌑",
          "rating": 9.1,
          "year": 6102,
          "runtime": "niṃ ƼƼ",
          "dimension": "upside_down"
        },
        {
          "season": 2,
          "episode": 9,
          "title": "ǝʇɐꓨ ǝɥ⊥",
          "emoji": "🕳️",
          "rating": 9.3,
          "year": 7102,
          "runtime": "niṃ ᘔ9",
          "dimension": "upside_down"
        },
        {
          "season": 3,
          "episode": 8,
          "title": "ʇɹnoɔɹɐʇS ɟo ǝlʇʇɐꓭ ǝɥ⊥",
          "emoji": "🎇",
          "rating": 9.4,
          "year": 9102,
          "runtime": "niṃ ㄥㄥ",
          "dimension": "upside_down"
        },
        {
          "season": 4,
          "episode": 9,
          "title": "ʞɔɐqʎƃƃᴉԀ ǝɥ⊥",
          "emoji": "⚡",
          "rating": 9.5,
          "year": 2202,
          "runtime": "niṃ 6Ɛ⇂",
          "dimension": "upside_down"
        }
      ],
      "characters": [
        {"name": "uǝʌǝlƎ", "emoji": "👾", "power": "sisǝuᴉʞǝlǝ⊥", "status": "pǝʇɹoʇsᴉp"},
        {"name": "ɹǝlǝǝɥM ǝʞᴉW", "emoji": "🎮", "role": "ɹǝpɐǝ˥", "status": "pǝʇɹoʇsᴉp"},
        {"name": "uosɹǝpuǝH uᴉʇsnꓷ", "emoji": "🎩", "trait": "ʇɹɐɯS", "status": "pǝʇɹoʇsᴉp"},
        {"name": "ɹᴉɐlɔuᴉS sɐɔn˥", "emoji": "🏹", "skill": "ʇǝʞɔoɹ ʇsᴉɹM", "status": "pǝʇɹoʇsᴉp"},
        {"name": "sɹǝʎꓭ llᴉM", "emoji": "🎨", "connection": "uʍoꓷ ǝpᴉsd∩", "status": "pǝddɐɹʇ"}
      ],
      "new_features": [
        "🔮 Mind Flayer detection algorithm",
        "🌀 Dimensional rift navigation",
        "🦇 Demobat swarm alerts",
        "⏰ Time-warped streaming (faster playback in the Upside Down)"
      ],
      "stats": {
        "total_episodes": 42,
        "total_seasons": 4,
        "active_viewers": 150000,
        "hawkins_population": "Unknown (dimension unstable)",
        "dimension": "upside_down",
        "stability": "experimental"
      }
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 🔴 STV-V2 (Upside Down) - Request: {s.path} from {s.client_address[0]}", flush=True)
        print(f"[{timestamp}] 🔴 STV-V2 - Processing in Upside Down dimension...", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-API-Version", "v2")
        s.send_header("X-Mode", "upside_down")
        s.send_header("X-Experimental", "true")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 🔴 STV-V2 - Response sent: 200 OK (Upside Down Mode)", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("🔴 STV-V2 starting on port 8080...", flush=True)
      print("🔴 Stranger Things API v2 - UPSIDE DOWN MODE (Tested by Dustin)", flush=True)
      print("⚠️  Experimental features enabled!", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
EOF

# Deploy stv-v1 (stable version)
echo "🎬 Deploying stv-v1 (stable version)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stv-v1
  namespace: hawkins
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stranger-things
      version: v1
  template:
    metadata:
      labels:
        app: stranger-things
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
          name: stv-v1-code
---
apiVersion: v1
kind: Service
metadata:
  name: stv-v1
  namespace: hawkins
spec:
  type: ClusterIP
  selector:
    app: stranger-things
    version: v1
  ports:
  - port: 8080
    targetPort: 8080
EOF

# Deploy stv-v2 (upside down mode)
echo "🌀 Deploying stv-v2 (experimental - upside down mode)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stv-v2
  namespace: hawkins
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stranger-things
      version: v2
  template:
    metadata:
      labels:
        app: stranger-things
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
          name: stv-v2-code
---
apiVersion: v1
kind: Service
metadata:
  name: stv-v2
  namespace: hawkins
spec:
  type: ClusterIP
  selector:
    app: stranger-things
    version: v2
  ports:
  - port: 8080
    targetPort: 8080
EOF

# Create str-gtw namespace
echo "🏗️ Creating str-gtw namespace..."
kubectl create namespace str-gtw > /dev/null 2>&1 || true

# Create Gateway
echo "🌉 Creating Gateway (stranger-gw)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: stranger-gw
  namespace: str-gtw
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: api.stranger.things
    allowedRoutes:
      namespaces: 
        from: Selector
        selector: 
          matchLabels:
            kubernetes.io/metadata.name: hawkins
EOF

# Wait for deployments
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/stv-v1 -n hawkins --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/stv-v2 -n hawkins --timeout=120s > /dev/null 2>&1

echo ""
echo "✅ Setup complete! Hawkins Lab is ready."
echo ""
echo "📋 Environment Overview:"
echo "   • Gateway Namespace: str-gtw"
echo "   • Application Namespace: hawkins"
echo "   • Services: stv-v1 (stable), stv-v2 (experimental)"
echo "   • Gateway: stranger-gw (str-gtw)"
echo ""
echo "🎯 Your CKA Task:"
echo "   Create an HTTPRoute named 'stranger-canary-route' that:"
echo "   • Attaches to Gateway 'stranger-gw' in namespace 'str-gtw'"
echo "   • Routes to host: api.stranger.things"
echo "   • Path prefix: /recommendations"
echo "   • Traffic split: 90% → stv-v1, 10% → stv-v2"
echo "   • Save to: /root/st-canary.yaml"
echo ""
echo "📊 Monitor traffic distribution:"
echo "   kubectl logs -f deployment/stv-v1 -n hawkins"
echo "   kubectl logs -f deployment/stv-v2 -n hawkins"
echo ""
echo "⏱️  Time limit: 7-10 minutes. Good luck! 🍀"
