#!/bin/bash
set -euo pipefail

echo "🎴 Initializing Borderland Game Environment..."
echo "⏱️  Timer started... Survive or die."
echo ""

# Install Gateway API CRDs
echo "📦 Installing Kubernetes Gateway API CRDs..."
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1

# Install NGINX Gateway Fabric
echo "🔌 Installing NGINX Gateway Fabric..."
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

sleep 3

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

sleep 3

# Create borderland namespace
echo "🏗️ Creating borderland namespace..."
kubectl create namespace borderland > /dev/null 2>&1 || true

# Create ConfigMap for games service
echo "🎮 Creating Game Services..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: games-service-code
  namespace: borderland
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "service": "Borderland Games Registry",
      "emoji": "🎴",
      "status": "active",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Welcome to the Borderland - Survive the Games",
      "current_stage": "Migration Challenge",
      "games": [
        {
          "id": 1,
          "name": "Five of Spades",
          "type": "♠️ Physical",
          "difficulty": 5,
          "description": "Tag game in a dark building",
          "status": "cleared",
          "survivors": 3,
          "casualties": 2
        },
        {
          "id": 2,
          "name": "Seven of Hearts",
          "type": "♥️ Psychological",
          "difficulty": 7,
          "description": "Wolf and Sheep game",
          "status": "cleared",
          "survivors": 2,
          "casualties": 3
        },
        {
          "id": 3,
          "name": "Ten of Hearts",
          "type": "♥️ Psychological",
          "difficulty": 10,
          "description": "Witch Hunt",
          "status": "cleared",
          "survivors": 4,
          "casualties": 6
        },
        {
          "id": 4,
          "name": "King of Spades",
          "type": "♠️ Physical",
          "difficulty": 10,
          "description": "Survival against King of Spades",
          "status": "active",
          "survivors": "unknown",
          "warning": "Extreme danger - armed combat"
        },
        {
          "id": 5,
          "name": "Queen of Hearts",
          "type": "♥️ Psychological",
          "difficulty": 10,
          "description": "Croquet game with the Queen",
          "status": "active",
          "survivors": "unknown",
          "warning": "Maximum difficulty"
        }
      ],
      "active_players": [
        {"name": "Arisu", "emoji": "👨", "specialty": "Strategy", "games_cleared": 12},
        {"name": "Usagi", "emoji": "👩", "specialty": "Physical", "games_cleared": 10},
        {"name": "Chishiya", "emoji": "😏", "specialty": "Intelligence", "games_cleared": 15},
        {"name": "Kuina", "emoji": "💪", "specialty": "Combat", "games_cleared": 11},
        {"name": "Tatta", "emoji": "🔧", "specialty": "Technical", "games_cleared": 8}
      ],
      "survival_guide": {
        "rule_1": "Always carry your visa",
        "rule_2": "Game difficulty increases with suit number",
        "rule_3": "♠️ Spades = Physical, ♥️ Hearts = Psychological, ♣️ Clubs = Balanced, ♦️ Diamonds = Intelligence",
        "rule_4": "Clear all face cards to return home",
        "rule_5": "Trust no one completely in the Borderland"
      },
      "days_remaining": "Unknown"
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 🎴 Games-Service - Request: {s.path}", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-Service", "games")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 🎴 Games-Service - Response: 200 OK", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("🎴 Borderland Games Service starting on port 8080...", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
EOF

# Create ConfigMap for players service
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: players-service-code
  namespace: borderland
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    
    data = {
      "service": "Borderland Players Registry",
      "emoji": "👥",
      "status": "active",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Player Database - Who Will Survive?",
      "total_players": 5,
      "players": [
        {
          "id": 1,
          "name": "Ryōhei Arisu",
          "nickname": "Arisu",
          "emoji": "👨",
          "age": 24,
          "specialty": "Strategic thinking and game theory",
          "games_cleared": 12,
          "highest_game": "King of Clubs",
          "visa_days": 3,
          "status": "alive",
          "background": "Unemployed gamer with exceptional analytical skills"
        },
        {
          "id": 2,
          "name": "Yuzuha Usagi",
          "nickname": "Usagi",
          "emoji": "👩",
          "age": 25,
          "specialty": "Mountain climbing and physical prowess",
          "games_cleared": 10,
          "highest_game": "King of Spades participation",
          "visa_days": 4,
          "status": "alive",
          "background": "Experienced climber seeking her father"
        },
        {
          "id": 3,
          "name": "Shuntarō Chishiya",
          "nickname": "Chishiya",
          "emoji": "😏",
          "age": 25,
          "specialty": "Medical knowledge and manipulation",
          "games_cleared": 15,
          "highest_game": "King of Diamonds",
          "visa_days": 5,
          "status": "alive",
          "background": "Medical student with cunning intelligence"
        },
        {
          "id": 4,
          "name": "Kuina Hikari",
          "nickname": "Kuina",
          "emoji": "💪",
          "age": 28,
          "specialty": "Martial arts and combat",
          "games_cleared": 11,
          "highest_game": "Jack of Hearts",
          "visa_days": 3,
          "status": "alive",
          "background": "Former martial artist seeking freedom"
        },
        {
          "id": 5,
          "name": "Kōdai Tatta",
          "nickname": "Tatta",
          "emoji": "🔧",
          "age": 22,
          "specialty": "Mechanical skills and courage",
          "games_cleared": 8,
          "highest_game": "Seven of Hearts",
          "visa_days": 2,
          "status": "alive",
          "background": "Factory worker with big heart"
        }
      ],
      "statistics": {
        "survival_rate": "32%",
        "most_dangerous_suit": "♥️ Hearts (Psychological)",
        "most_cleared_suit": "♣️ Clubs (Balanced)",
        "average_visa_days": 3.4
      },
      "warnings": [
        "⚠️ Visa expiration means immediate death",
        "⚠️ King of Spades is actively hunting players",
        "⚠️ Trust is the rarest resource in Borderland",
        "⚠️ Face card games are extremely dangerous"
      ]
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 👥 Players-Service - Request: {s.path}", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-Service", "players")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 👥 Players-Service - Response: 200 OK", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("👥 Borderland Players Service starting on port 8080...", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
EOF

# Deploy games service
echo "🎴 Deploying games service..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: games-service
  namespace: borderland
spec:
  replicas: 2
  selector:
    matchLabels:
      app: games
  template:
    metadata:
      labels:
        app: games
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
          name: games-service-code
---
apiVersion: v1
kind: Service
metadata:
  name: games-service
  namespace: borderland
spec:
  type: ClusterIP
  selector:
    app: games
  ports:
  - port: 80
    targetPort: 8080
EOF

# Deploy players service
echo "👥 Deploying players service..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: players-service
  namespace: borderland
spec:
  replicas: 2
  selector:
    matchLabels:
      app: players
  template:
    metadata:
      labels:
        app: players
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
          name: players-service-code
---
apiVersion: v1
kind: Service
metadata:
  name: players-service
  namespace: borderland
spec:
  type: ClusterIP
  selector:
    app: players
  ports:
  - port: 80
    targetPort: 8080
EOF

# Wait for deployments
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/games-service -n borderland --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/players-service -n borderland --timeout=120s > /dev/null 2>&1

# Create TLS certificate
echo "🔒 Creating TLS certificate for HTTPS..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=gateway.web.k8s.local/O=Borderland" > /dev/null 2>&1

kubectl create secret tls web-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n borderland > /dev/null 2>&1 || true

# Install NGINX Ingress Controller
echo "🔧 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml > /dev/null 2>&1

echo "⏳ Waiting for Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s > /dev/null 2>&1 || echo "Ingress controller initializing..."

sleep 2


# Ensure directory exists
mkdir -p /borderland-ingress

# Write ingress.yaml
cat <<'EOF' > /borderland-ingress/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: borderland
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - gateway.web.k8s.local
    secretName: web-tls
  rules:
  - host: gateway.web.k8s.local
    http:
      paths:
      - path: /games
        pathType: Prefix
        backend:
          service:
            name: games-service
            port:
              number: 80
      - path: /players
        pathType: Prefix
        backend:
          service:
            name: players-service
            port:
              number: 80
EOF

echo "📄 Saved Ingress file to /borderland-ingress/ingress.yaml"

# Apply to Kubernetes
kubectl apply -f /borderland-ingress/ingress.yaml

echo "📡 Ingress applied."


echo ""
echo "✅ Borderland Game Environment Ready!"
echo ""
echo "🎴 ═══════════════════════════════════════════════════════════"
echo "   THE MIGRATION GAME - ♠️ Difficulty 8/10"
echo "   ═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Current Setup:"
echo "   • Namespace: borderland"
echo "   • Existing Ingress: web"
echo "   • Services: games-service, players-service"
echo "   • TLS Secret: web-tls"
echo "   • Hostname: gateway.web.k8s.local"
echo ""
echo "🎯 YOUR MISSION:"
echo "   1. Analyze existing Ingress resource 'web'"
echo "   2. Create Gateway 'web-gateway' with TLS configuration"
echo "   3. Create HTTPRoute 'web-route' with routing rules"
echo "   4. Maintain HTTPS access and path-based routing"
echo ""
echo "⏱️  TIME LIMIT: 10-15 minutes"
echo ""
echo "💡 Examine the Ingress:"
echo "   kubectl get ingress web -n borderland -o yaml"
echo ""
echo "⚠️  GAME RULES:"
echo "   • Gateway name: web-gateway"
echo "   • HTTPRoute name: web-route"
echo "   • Hostname: gateway.web.k8s.local"
echo "   • Maintain TLS termination (HTTPS)"
echo "   • Preserve /games and /players routes"
echo ""
echo "🃏 Clear Condition: Both resources functional with HTTPS access"
echo ""
echo "💀 Failure Condition: Time runs out or incorrect configuration"
echo ""
echo "⏱️  The game has begun. Survive or perish!"
echo ""
