#!/bin/bash
set -euo pipefail

echo "🎮 Setting up Kanto Research Cloud Platform..."
echo "192.168.1.240 pokedex.kanto.lab" | sudo tee -a /etc/hosts
# Install Gateway API CRDs
echo "📦 Installing Kubernetes Gateway API CRDs..."
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1

# Install NGINX Gateway Fabric
echo "⚡ Installing NGINX Gateway Fabric..."
helm repo add nginx-stable https://helm.nginx.com/stable > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n gateway-system --wait > /dev/null 2>&1

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

# Create namespaces
echo "🏗️ Creating namespaces..."
kubectl create namespace pokedex-ui > /dev/null 2>&1 || true
kubectl create namespace pokedex-core > /dev/null 2>&1 || true

# Create ConfigMap for evolution-engine service
echo "📝 Creating ConfigMap for evolution-engine..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: evolution-engine-code
  namespace: pokedex-core
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "service": "Evolution Engine",
      "emoji": "⚡",
      "namespace": "pokedex-core",
      "version": "v1.0",
      "status": "operational",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Pokémon Evolution Data Service - Kanto Research Lab",
      "professor": "Professor Oak",
      "evolutions": [
        {
          "pokemon": "Charmander",
          "number": 4,
          "emoji": "🔥",
          "type": "Fire",
          "evolves_to": "Charmeleon",
          "level": 16,
          "final_evolution": "Charizard",
          "final_level": 36
        },
        {
          "pokemon": "Squirtle",
          "number": 7,
          "emoji": "💧",
          "type": "Water",
          "evolves_to": "Wartortle",
          "level": 16,
          "final_evolution": "Blastoise",
          "final_level": 36
        },
        {
          "pokemon": "Bulbasaur",
          "number": 1,
          "emoji": "🌱",
          "type": "Grass/Poison",
          "evolves_to": "Ivysaur",
          "level": 16,
          "final_evolution": "Venusaur",
          "final_level": 32
        },
        {
          "pokemon": "Pikachu",
          "number": 25,
          "emoji": "⚡",
          "type": "Electric",
          "evolves_to": "Raichu",
          "level": "Thunder Stone",
          "final_evolution": "Raichu",
          "note": "Evolution requires Thunder Stone"
        },
        {
          "pokemon": "Eevee",
          "number": 133,
          "emoji": "🦊",
          "type": "Normal",
          "evolutions": [
            {"name": "Vaporeon", "method": "Water Stone", "emoji": "💧"},
            {"name": "Jolteon", "method": "Thunder Stone", "emoji": "⚡"},
            {"name": "Flareon", "method": "Fire Stone", "emoji": "🔥"}
          ]
        },
        {
          "pokemon": "Geodude",
          "number": 74,
          "emoji": "🪨",
          "type": "Rock/Ground",
          "evolves_to": "Graveler",
          "level": 25,
          "final_evolution": "Golem",
          "final_level": "Trade"
        },
        {
          "pokemon": "Machop",
          "number": 66,
          "emoji": "💪",
          "type": "Fighting",
          "evolves_to": "Machoke",
          "level": 28,
          "final_evolution": "Machamp",
          "final_level": "Trade"
        },
        {
          "pokemon": "Abra",
          "number": 63,
          "emoji": "🔮",
          "type": "Psychic",
          "evolves_to": "Kadabra",
          "level": 16,
          "final_evolution": "Alakazam",
          "final_level": "Trade"
        }
      ],
      "stats": {
        "total_evolutions": 8,
        "stone_evolutions": 4,
        "trade_evolutions": 3,
        "level_evolutions": 7
      },
      "research_notes": [
        "Evolution stones can be found in various locations across Kanto",
        "Trading is required for some final evolutions",
        "Pokémon happiness affects some evolution methods",
        "Some Pokémon evolve only at specific times or locations"
      ]
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] ⚡ Evolution-Engine - Request: {s.path} from {s.client_address[0]}", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-Service", "evolution-engine")
        s.send_header("X-Namespace", "pokedex-core")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] ⚡ Evolution-Engine - Response sent: 200 OK", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("⚡ Evolution Engine starting on port 9000...", flush=True)
      print("⚡ Pokémon Evolution Data Service (pokedex-core namespace)", flush=True)
      print("⚡ Professor Oak's Research Lab - Ready!", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 9000), Handler).serve_forever()
EOF

# Deploy evolution-engine service
echo "⚡ Deploying evolution-engine service..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: evolution-engine
  namespace: pokedex-core
spec:
  replicas: 2
  selector:
    matchLabels:
      app: evolution-engine
  template:
    metadata:
      labels:
        app: evolution-engine
    spec:
      containers:
      - name: api
        image: python:3.11-slim
        ports:
        - containerPort: 9000
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
          name: evolution-engine-code
---
apiVersion: v1
kind: Service
metadata:
  name: evolution-engine
  namespace: pokedex-core
  labels:
    app: evolution-engine
spec:
  type: ClusterIP
  selector:
    app: evolution-engine
  ports:
  - port: 9000
    targetPort: 9000
    name: http
EOF

# Wait for deployment
echo "⏳ Waiting for evolution-engine to be ready..."
kubectl wait --for=condition=available deployment/evolution-engine -n pokedex-core --timeout=120s > /dev/null 2>&1

# Create Gateway
echo "🌉 Creating Gateway (kanto-gateway)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kanto-gateway
  namespace: gateway-system
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: pokedex.kanto.lab
    allowedRoutes:
      namespaces: 
        from: All
EOF

# Create HTTPRoute (without ReferenceGrant - this will be blocked)
echo "📡 Creating HTTPRoute (will be blocked without ReferenceGrant)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: trainer-api-route
  namespace: pokedex-ui
spec:
  parentRefs:
  - name: kanto-gateway
    namespace: gateway-system
  hostnames:
  - "pokedex.kanto.lab"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: "/api/evolution"
    backendRefs:
    - name: evolution-engine
      namespace: pokedex-core
      port: 9000
EOF

sleep 3

echo ""
echo "✅ Setup complete! Kanto Research Platform is ready."
echo ""
echo "🚨 PROBLEM DETECTED:"
echo "   HTTPRoute 'trainer-api-route' in namespace 'pokedex-ui'"
echo "   is trying to access Service 'evolution-engine' in namespace 'pokedex-core'"
echo ""
echo "   ❌ Error: Cross-namespace reference denied - missing ReferenceGrant"
echo ""
echo "📋 Environment Overview:"
echo "   • Gateway Namespace: gateway-system"
echo "   • Gateway: kanto-gateway"
echo "   • Frontend Namespace: pokedex-ui (HTTPRoute)"
echo "   • Backend Namespace: pokedex-core (Service)"
echo "   • Service: evolution-engine (port 9000)"
echo "   • HTTPRoute: trainer-api-route"
echo ""
echo "🎯 Your CKA Task:"
echo "   Create a ReferenceGrant in namespace 'pokedex-core' that:"
echo "   • Allows HTTPRoute from 'pokedex-ui' namespace"
echo "   • Grants access to Service 'evolution-engine'"
echo "   • Does NOT wildcard other resources"
echo "   • Save to: /root/poke-refgrant.yaml"
echo ""
echo "💡 Verify the issue:"
echo "   kubectl describe httproute trainer-api-route -n pokedex-ui"
echo ""
echo "⏱️  Time limit: 5-8 minutes. Good luck, Trainer! 🎮"
