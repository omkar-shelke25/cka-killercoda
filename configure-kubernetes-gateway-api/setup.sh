#!/bin/bash
set -euo pipefail

echo "🚄 Setting up Japan Bullet Train Booking System..."

# Install Gateway API CRDs
echo "📦 Installing Kubernetes Gateway API CRDs..."
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/experimental?ref=v1.6.2" | kubectl apply -f - > /dev/null 2>&1

# Install NGINX Gateway Fabric
echo "🔌 Installing NGINX Gateway Fabric..."
helm repo add nginx-stable https://helm.nginx.com/stable > /dev/null 2>&1 || true
helm repo update > /dev/null 2>&1
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway --wait > /dev/null 2>&1

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

# Deploy the three microservices with full data and icons
echo "🚅 Deploying Bullet Train microservices..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Namespace
metadata:
  name: jp-bullet-train-app-prod
---
# REFERENCE GRANT - For cross-namespace routing
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-services
  namespace: jp-bullet-train-app-prod
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: jp-bullet-train-gtw
  to:
  - group: ""
    kind: Service
---
# 1. AVAILABLE TRAINS SERVICE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: available
  namespace: jp-bullet-train-app-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: available
  template:
    metadata:
      labels:
        app: available
    spec:
      containers:
      - name: server
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
        command: ["python", "-c"]
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          data = {
            "endpoint": "available",
            "endpoint_icon": "🚄",
            "theme": "japan-bullet", 
            "icon": "train",
            "description": "Real-time availability of Japan's Shinkansen bullet trains",
            "last_updated": "2025-11-30T14:30:00Z",
            "total_trains": 12,
            "trains_available": 8,
            "trains_maintenance": 1,
            "trains_testing": 1,
            "message": "Welcome to Japan Railway's real-time train availability system",
            "bullets": [
              {"id":"N700S",      "icon":"🚄", "emoji":"🚄", "name":"N700S Supreme",     "status":"available",    "capacity":1323, "speed_kmh":285, "route":"Tokaido-Sanyo"},
              {"id":"H5",         "icon":"🚅", "emoji":"🚅", "name":"H5 Hokkaido",       "status":"available",    "capacity":731,  "speed_kmh":320, "route":"Hokkaido"},
              {"id":"E7",         "icon":"🚆", "emoji":"🚆", "name":"E7 Hokuriku",       "status":"limited",      "capacity":934,  "speed_kmh":260, "route":"Hokuriku"},
              {"id":"E5",         "icon":"🚄", "emoji":"🚄", "name":"Hayabusa E5",       "status":"available",    "capacity":731,  "speed_kmh":320, "route":"Tohoku"},
              {"id":"E6",         "icon":"🚅", "emoji":"🚅", "name":"Komachi E6",        "status":"maintenance",  "capacity":338,  "speed_kmh":320, "route":"Akita", "maintenance_until":"2025-12-02"},
              {"id":"800",        "icon":"🚇", "emoji":"🚇", "name":"800 Sakura",        "status":"available",    "capacity":546,  "speed_kmh":260, "route":"Kyushu"},
              {"id":"DoctorYellow","icon":"🟡", "emoji":"🟡", "name":"Doctor Yellow",     "status":"testing",      "capacity":0,    "speed_kmh":270, "route":"Inspection", "note":"Track inspection train"},
              {"id":"Genbi",      "icon":"🎨", "emoji":"🎨", "name":"Genbi Art Train",   "status":"available",    "capacity":250,  "speed_kmh":130, "route":"Joetsu", "special":"Mobile art gallery"},
              {"id":"KODAMA",     "icon":"🚃", "emoji":"🚃", "name":"Kodama",            "status":"available",    "capacity":1323, "speed_kmh":220, "route":"Tokaido"},
              {"id":"HIKARI",     "icon":"⭐", "emoji":"⭐", "name":"Hikari",            "status":"limited",      "capacity":1229, "speed_kmh":285, "route":"Tokaido-Sanyo"},
              {"id":"MIZUHO",     "icon":"💧", "emoji":"💧", "name":"Mizuho",            "status":"available",    "capacity":1323, "speed_kmh":300, "route":"Sanyo-Kyushu"},
              {"id":"SAKURA",     "icon":"🌸", "emoji":"🌸", "name":"Sakura",            "status":"available",    "capacity":1323, "speed_kmh":300, "route":"Sanyo-Kyushu"}
            ],
            "status_legend": {
              "available": "✅ Ready for booking",
              "limited": "⚠️ Limited seats remaining",
              "maintenance": "🔧 Under maintenance",
              "testing": "🧪 Testing/Inspection"
            }
          }
          class H(BaseHTTPRequestHandler):
            def do_GET(s):
              s.send_response(200)
              s.send_header("Content-Type", "application/json; charset=utf-8")
              s.send_header("Access-Control-Allow-Origin", "*")
              s.end_headers()
              s.wfile.write(json.dumps(data, ensure_ascii=False, indent=2).encode())
          HTTPServer(("",8080),H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: available
  namespace: jp-bullet-train-app-prod
spec:
  type: ClusterIP
  selector: 
    app: available
  ports: 
  - port: 80
    targetPort: 8080

---
# 2. BOOKINGS SERVICE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: books
  namespace: jp-bullet-train-app-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: books
  template:
    metadata:
      labels:
        app: books
    spec:
      containers:
      - name: server
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
        command: ["python", "-c"]
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          data = {
            "endpoint": "books",
            "endpoint_icon": "📕",
            "theme": "japan-bullet", 
            "icon": "red book",
            "description": "Real-time booking status for all Shinkansen trains",
            "last_updated": "2025-11-30T14:30:00Z",
            "total_bookings": 8459,
            "total_capacity": 10033,
            "occupancy_rate": "84.3%",
            "message": "Booking system online. 2 trains fully booked.",
            "bookings": [
              {"id":"N700S",       "icon":"🚄", "emoji":"🚄", "fullyBooked":False, "bookedSeats":998,  "capacity":1323, "available":325,  "occupancy":"75.4%", "status":"🟢"},
              {"id":"H5",          "icon":"🚅", "emoji":"🚅", "fullyBooked":False, "bookedSeats":612,  "capacity":731,  "available":119,  "occupancy":"83.7%", "status":"🟡"},
              {"id":"E7",          "icon":"🚆", "emoji":"🚆", "fullyBooked":True,  "bookedSeats":934,  "capacity":934,  "available":0,    "occupancy":"100%",  "status":"🔴"},
              {"id":"E5",          "icon":"🚄", "emoji":"🚄", "fullyBooked":False, "bookedSeats":699,  "capacity":731,  "available":32,   "occupancy":"95.6%", "status":"🟠"},
              {"id":"E6",          "icon":"🚅", "emoji":"🚅", "fullyBooked":True,  "bookedSeats":338,  "capacity":338,  "available":0,    "occupancy":"100%",  "status":"🔴"},
              {"id":"800",         "icon":"🚇", "emoji":"🚇", "fullyBooked":False, "bookedSeats":412,  "capacity":546,  "available":134,  "occupancy":"75.5%", "status":"🟢"},
              {"id":"DoctorYellow","icon":"🟡", "emoji":"🟡", "fullyBooked":False, "bookedSeats":0,    "capacity":0,    "available":0,    "occupancy":"N/A",   "status":"⚪", "note":"Not bookable"},
              {"id":"Genbi",       "icon":"🎨", "emoji":"🎨", "fullyBooked":False, "bookedSeats":198,  "capacity":250,  "available":52,   "occupancy":"79.2%", "status":"🟢"},
              {"id":"KODAMA",      "icon":"🚃", "emoji":"🚃", "fullyBooked":False, "bookedSeats":1102, "capacity":1323, "available":221,  "occupancy":"83.3%", "status":"🟡"},
              {"id":"HIKARI",      "icon":"⭐", "emoji":"⭐", "fullyBooked":True,  "bookedSeats":1229, "capacity":1229, "available":0,    "occupancy":"100%",  "status":"🔴"},
              {"id":"MIZUHO",      "icon":"💧", "emoji":"💧", "fullyBooked":False, "bookedSeats":876,  "capacity":1323, "available":447,  "occupancy":"66.2%", "status":"🟢"},
              {"id":"SAKURA",      "icon":"🌸", "emoji":"🌸", "fullyBooked":False, "bookedSeats":921,  "capacity":1323, "available":402,  "occupancy":"69.6%", "status":"🟢"}
            ],
            "occupancy_legend": {
              "🟢": "Available (0-80% booked)",
              "🟡": "Filling up (80-95% booked)",
              "🟠": "Almost full (95-99% booked)",
              "🔴": "Fully booked (100%)",
              "⚪": "Not bookable"
            },
            "booking_tips": [
              "💡 Book early for weekend travel",
              "🎫 Green Car seats available on most trains",
              "📱 Mobile tickets available via JR app",
              "🎒 Large luggage requires reservation"
            ]
          }
          class H(BaseHTTPRequestHandler):
            def do_GET(s):
              s.send_response(200)
              s.send_header("Content-Type", "application/json; charset=utf-8")
              s.send_header("Access-Control-Allow-Origin", "*")
              s.end_headers()
              s.wfile.write(json.dumps(data, ensure_ascii=False, indent=2).encode())
          HTTPServer(("",8080),H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: books
  namespace: jp-bullet-train-app-prod
spec:
  type: ClusterIP
  selector:
    app: books
  ports:
  - port: 80
    targetPort: 8080

---
# 3. TRAVELLERS SERVICE (with real yen prices)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: travellers
  namespace: jp-bullet-train-app-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: travellers
  template:
    metadata:
      labels:
        app: travellers
    spec:
      containers:
      - name: server
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
        command: ["python", "-c"]
        args:
        - |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          import json
          data = {
            "endpoint": "travellers",
            "endpoint_icon": "🛂",
            "theme": "japan-bullet", 
            "icon": "passport control",
            "description": "Current passenger manifest for today's Shinkansen services",
            "last_updated": "2025-11-30T14:30:00Z",
            "total_travellers": 12,
            "total_revenue": "¥273,770",
            "message": "12 active bookings across 10 different train services",
            "travellers": [
              {"travellerId":"TR001","icon":"👘","emoji":"👘","name":"山田 愛子","bulletId":"N700S","seat":"15C","ticket_price":"¥18,520","class":"普通車","destination":"Osaka","departure":"Tokyo"},
              {"travellerId":"TR002","icon":"🎒","emoji":"🎒","name":"佐藤 陽翔","bulletId":"H5","seat":"8A","ticket_price":"¥32,100","class":"グリーン車","destination":"Sapporo","departure":"Tokyo"},
              {"travellerId":"TR003","icon":"👘","emoji":"👘","name":"中村 結衣","bulletId":"E7","seat":"3B","ticket_price":"¥24,800","class":"普通車","destination":"Kanazawa","departure":"Tokyo"},
              {"travellerId":"TR004","icon":"💼","emoji":"💼","name":"鈴木 大地","bulletId":"E5","seat":"22D","ticket_price":"¥38,900","class":"グリーン車","destination":"Aomori","departure":"Tokyo"},
              {"travellerId":"TR005","icon":"🎨","emoji":"🎨","name":"Rina Artista","bulletId":"Genbi","seat":"1A","ticket_price":"¥12,000","class":"特別車","destination":"Echigo-Yuzawa","departure":"Niigata","special":"Art tour passenger"},
              {"travellerId":"TR006","icon":"🌸","emoji":"🌸","name":"森 さくら","bulletId":"SAKURA","seat":"10E","ticket_price":"¥19,750","class":"普通車","destination":"Kumamoto","departure":"Osaka"},
              {"travellerId":"TR007","icon":"👷","emoji":"👷","name":"田中 太郎","bulletId":"DoctorYellow","seat":"運転席","ticket_price":"¥0","class":"係員","destination":"Tokyo","departure":"Osaka","role":"Inspection crew"},
              {"travellerId":"TR008","icon":"🌏","emoji":"🌏","name":"王 美玲","bulletId":"MIZUHO","seat":"7F","ticket_price":"¥28,300","class":"グリーン車","destination":"Kagoshima","departure":"Shin-Osaka"},
              {"travellerId":"TR009","icon":"⚔️","emoji":"⚔️","name":"侍 健司","bulletId":"KODAMA","seat":"19B","ticket_price":"¥14,200","class":"普通車","destination":"Nagoya","departure":"Tokyo"},
              {"travellerId":"TR010","icon":"📷","emoji":"📷","name":"Luna Railfan","bulletId":"E6","seat":"5C","ticket_price":"¥21,500","class":"普通車","destination":"Akita","departure":"Tokyo","interest":"Railway photography"},
              {"travellerId":"TR011","icon":"☀️","emoji":"☀️","name":"光 陽子","bulletId":"HIKARI","seat":"12A","ticket_price":"¥26,800","class":"普通車","destination":"Hiroshima","departure":"Tokyo"},
              {"travellerId":"TR012","icon":"🗺️","emoji":"🗺️","name":"探検家 健","bulletId":"800","seat":"4D","ticket_price":"¥16,900","class":"普通車","destination":"Hakata","departure":"Kumamoto"}
            ],
            "class_legend": {
              "普通車": "🔵 Ordinary Car (Standard)",
              "グリーン車": "🟢 Green Car (First Class)",
              "特別車": "⭐ Special Car (Premium)",
              "係員": "👨‍✈️ Staff/Crew"
            },
            "travel_stats": {
              "most_popular_route": "Tokyo → Osaka (N700S)",
              "longest_journey": "Tokyo → Kagoshima (MIZUHO, ¥28,300)",
              "shortest_journey": "Tokyo → Nagoya (KODAMA, ¥14,200)",
              "green_car_percentage": "33.3%"
            },
            "service_info": [
              "🍱 Ekiben (lunch boxes) available on board",
              "📶 Free WiFi on all services",
              "🔌 Power outlets at every seat",
              "♿ Accessible seating available"
            ]
          }
          class H(BaseHTTPRequestHandler):
            def do_GET(s):
              s.send_response(200)
              s.send_header("Content-Type", "application/json; charset=utf-8")
              s.send_header("Access-Control-Allow-Origin", "*")
              s.end_headers()
              s.wfile.write(json.dumps(data, ensure_ascii=False, indent=2).encode())
          HTTPServer(("",8080),H).serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: travellers
  namespace: jp-bullet-train-app-prod
spec:
  type: ClusterIP
  selector:
    app: travellers
  ports:
  - port: 80
    targetPort: 8080
EOF

# Wait for deployments to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available deployment/available -n jp-bullet-train-app-prod --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/books -n jp-bullet-train-app-prod --timeout=120s > /dev/null 2>&1
kubectl wait --for=condition=available deployment/travellers -n jp-bullet-train-app-prod --timeout=120s > /dev/null 2>&1

# Create gateway namespace
echo "🏗️  Creating gateway namespace..."
kubectl create namespace jp-bullet-train-gtw > /dev/null 2>&1 || true

# Create a self-signed TLS certificate
echo "🔐 Creating TLS certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=bullet.train.io/O=JR-Railway" > /dev/null 2>&1

# Create TLS secret in gateway namespace
kubectl create secret tls bullet-train-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  -n jp-bullet-train-gtw > /dev/null 2>&1 || true

# Create GatewayClass if not exists
echo "🎓 Creating GatewayClass..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
EOF

# Create task directory
mkdir -p /bullet-train

echo "✅ Setup complete! Japan Bullet Train Booking System is ready."
echo ""
echo "📋 Environment Overview:"
echo "   • Gateway Namespace: jp-bullet-train-gtw"
echo "   • Application Namespace: jp-bullet-train-app-prod"
echo "   • Services: available, books, travellers"
echo "   • TLS Secret: bullet-train-tls (already created)"
echo ""
echo "🎯 Your task: Configure Gateway and HTTPRoute to expose services at:"
echo "   • https://bullet.train.io/available"
echo "   • https://bullet.train.io/books"
echo "   • https://bullet.train.io/travellers"
