#!/bin/bash
set -euo pipefail

echo "🛒 Setting up AcmeRetail Holiday Flash Sale Environment..."
echo ""

# Create priority namespace
echo "🏗️ Creating priority namespace..."
kubectl create namespace priority > /dev/null 2>&1 || true

# Create user-defined PriorityClasses
echo "📊 Creating existing PriorityClasses for various teams..."

# Payment team - highest priority (critical transactions)
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: payment-critical
value: 1000000
globalDefault: false
description: "Critical priority for payment processing services"
EOF

# Inventory team - high priority
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: inventory-high
value: 800000
globalDefault: false
description: "High priority for inventory management services"
EOF

# Frontend team - medium priority
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: frontend-medium
value: 500000
globalDefault: false
description: "Medium priority for customer-facing services"
EOF

# Analytics team - low priority
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: analytics-low
value: 100000
globalDefault: false
description: "Low priority for analytics and reporting services"
EOF

# Create log forwarder service (without PriorityClass)
echo "📝 Creating log forwarder deployment (missing PriorityClass)..."
cat <<'EOF' | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: log-forwarder-config
  namespace: priority
data:
  forwarder.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json
    import datetime
    import sys
    import random
    
    # Simulate log collection stats
    logs_forwarded = random.randint(100000, 500000)
    
    data = {
      "service": "AcmeRetail Log Forwarder",
      "emoji": "📋",
      "status": "operational",
      "environment": "production",
      "event": "Holiday Flash Sale Preparation",
      "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
      "message": "Collecting and forwarding transaction logs to SIEM",
      "current_priority": "⚠️ NO PRIORITY CLASS ASSIGNED",
      "risk": "HIGH - May be evicted during resource pressure",
      "logs_today": {
        "total_forwarded": logs_forwarded,
        "transactions": logs_forwarded * 0.6,
        "fraud_alerts": random.randint(50, 200),
        "compliance_events": random.randint(100, 500),
        "errors": random.randint(0, 10)
      },
      "destinations": [
        {
          "name": "Splunk SIEM",
          "status": "connected",
          "endpoint": "siem.acmeretail.com:9997",
          "protocol": "TCP"
        },
        {
          "name": "S3 Archive",
          "status": "connected",
          "bucket": "acme-logs-archive",
          "retention": "7 years"
        },
        {
          "name": "Compliance Database",
          "status": "connected",
          "type": "PostgreSQL"
        }
      ],
      "critical_logs": [
        "Payment transactions",
        "User authentication",
        "Fraud detection events",
        "PCI-DSS audit trail",
        "Inventory updates",
        "Order placements"
      ],
      "flash_sale_readiness": {
        "buffer_capacity": "85%",
        "network_bandwidth": "Ready",
        "siem_connection": "Stable",
        "expected_volume": "500% increase",
        "concerns": [
          "⚠️ Missing PriorityClass - risk of pod eviction",
          "⚠️ Could lose logs during peak traffic",
          "⚠️ Compliance violations if logs are lost"
        ]
      },
      "requirements": {
        "priority_level": "Must be just below payment-critical",
        "reason": "Transaction logs required for fraud detection and compliance",
        "uptime_target": "99.99%"
      }
    }
    
    class Handler(BaseHTTPRequestHandler):
      def do_GET(s):
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[{timestamp}] 📋 Log-Forwarder - Health check received", flush=True)
        
        s.send_response(200)
        s.send_header("Content-Type", "application/json; charset=utf-8")
        s.send_header("X-Service", "log-forwarder")
        s.send_header("Access-Control-Allow-Origin", "*")
        s.end_headers()
        response_data = data.copy()
        response_data["timestamp"] = datetime.datetime.utcnow().isoformat() + "Z"
        s.wfile.write(json.dumps(response_data, ensure_ascii=False, indent=2).encode())
        
        print(f"[{timestamp}] 📋 Log-Forwarder - Response sent", flush=True)
      
      def log_message(self, format, *args):
        pass
    
    if __name__ == '__main__':
      print("📋 AcmeRetail Log Forwarder starting on port 8080...", flush=True)
      print("⚠️  WARNING: No PriorityClass configured!", flush=True)
      print("⚠️  Risk: Service may be evicted during resource pressure", flush=True)
      sys.stdout.flush()
      HTTPServer(("", 8080), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: acme-log-forwarder
  namespace: priority
spec:
  replicas: 2
  selector:
    matchLabels:
      app: log-forwarder
  template:
    metadata:
      labels:
        app: log-forwarder
        component: logging
        criticality: high
    spec:
      containers:
      - name: forwarder
        image: python:3.11-slim
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        command: ["python", "-u", "/app/forwarder.py"]
        volumeMounts:
        - name: config
          mountPath: /app
      volumes:
      - name: config
        configMap:
          name: log-forwarder-config
---
apiVersion: v1
kind: Service
metadata:
  name: log-forwarder-service
  namespace: priority
spec:
  type: ClusterIP
  selector:
    app: log-forwarder
  ports:
  - port: 80
    targetPort: 8080
EOF

# Wait for deployment
echo "⏳ Waiting for log forwarder deployment..."
kubectl wait --for=condition=available deployment/acme-log-forwarder -n priority --timeout=120s > /dev/null 2>&1

echo ""
echo "✅ AcmeRetail Holiday Flash Sale Environment Ready!"
echo ""
echo "🛒 ═══════════════════════════════════════════════════════════"
echo "   ACMERETAIL HOLIDAY FLASH SALE - PRIORITY CONFIGURATION"
echo "   ═══════════════════════════════════════════════════════════"
echo ""
echo "📊 Current PriorityClasses in Cluster:"
echo ""
kubectl get priorityclasses --no-headers 2>/dev/null | awk '{printf "   • %-30s (value: %s)\n", $1, $2}'
echo ""
echo "⚠️  CRITICAL ISSUE DETECTED:"
echo "   Deployment 'acme-log-forwarder' in namespace 'priority'"
echo "   is running WITHOUT a PriorityClass!"
echo ""
echo "🎯 YOUR MISSION:"
echo "   1. Find the highest user-defined PriorityClass value"
echo "      (Exclude system-cluster-critical and system-node-critical)"
echo ""
echo "   2. Create a new PriorityClass named 'high-priority'"
echo "      • Value: One less than highest user-defined PriorityClass"
echo "      • globalDefault: false"
echo "      • preemptionPolicy: PreemptLowerPriority"
echo ""
echo "   3. Update Deployment 'acme-log-forwarder' to use 'high-priority'"
echo "      in the namespace 'priority'"
echo ""
echo "⏱️  TIME LIMIT: 8-10 minutes"
echo ""
echo "💡 HINTS:"
echo "   • Check PriorityClasses: kubectl get priorityclasses"
echo "   • Get values: kubectl get pc <name> -o yaml"
echo "   • Edit deployment: kubectl edit deployment acme-log-forwarder -n priority"
echo ""
echo "🎁 Flash Sale starts soon! Configure priority NOW!"
echo ""
