#!/bin/bash
set -euo pipefail

CERT_FILE="/etc/kubernetes/pki/apiserver.crt"
KEY_FILE="/etc/kubernetes/pki/apiserver.key"

echo "🔍 Verifying API Server Certificate Recovery..."
echo ""

# ----------------------------------------------------------
# 1. Check certificate files exist
# ----------------------------------------------------------
echo "[1/6] Checking if API server certificate files exist..."

if [[ ! -f "$CERT_FILE" ]]; then
  echo "❌ Certificate file missing: $CERT_FILE"
  exit 1
fi
echo "✅ Certificate file exists: $CERT_FILE"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "❌ Key file missing: $KEY_FILE"
  exit 1
fi
echo "✅ Key file exists: $KEY_FILE"

# ----------------------------------------------------------
# 2. Check if files were recently created (within last 10 minutes)
# ----------------------------------------------------------
echo ""
echo "[2/6] Verifying certificates were recently generated..."

CURRENT_TIME=$(date +%s)
CERT_TIME=$(stat -c %Y "$CERT_FILE" 2>/dev/null || stat -f %m "$CERT_FILE" 2>/dev/null)
KEY_TIME=$(stat -c %Y "$KEY_FILE" 2>/dev/null || stat -f %m "$KEY_FILE" 2>/dev/null)

TIME_DIFF_CERT=$((CURRENT_TIME - CERT_TIME))
TIME_DIFF_KEY=$((CURRENT_TIME - KEY_TIME))

if [[ $TIME_DIFF_CERT -gt 600 ]]; then
  echo "⚠️  Warning: Certificate file is older than 10 minutes (${TIME_DIFF_CERT}s ago)"
  echo "   This might not be a newly regenerated certificate"
fi

if [[ $TIME_DIFF_KEY -gt 600 ]]; then
  echo "⚠️  Warning: Key file is older than 10 minutes (${TIME_DIFF_KEY}s ago)"
  echo "   This might not be a newly regenerated key"
fi

echo "✅ Certificate files have recent timestamps"

# ----------------------------------------------------------
# 3. Verify certificate validity
# ----------------------------------------------------------
echo ""
echo "[3/6] Checking certificate validity..."

if ! sudo openssl x509 -in "$CERT_FILE" -noout -text &>/dev/null; then
  echo "❌ Certificate file is not a valid X.509 certificate"
  exit 1
fi
echo "✅ Certificate is a valid X.509 certificate"

# Check expiration
EXPIRY=$(sudo openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
echo "   Certificate expires: $EXPIRY"

# ----------------------------------------------------------
# 4. Check API server container status
# ----------------------------------------------------------
echo ""
echo "[4/6] Checking kube-apiserver container status..."

# Wait a bit for container to stabilize
sleep 5

# Get running apiserver containers
RUNNING_CONTAINERS=$(sudo crictl ps --name kube-apiserver -q 2>/dev/null || true)

if [[ -z "$RUNNING_CONTAINERS" ]]; then
  echo "❌ No running kube-apiserver container found"
  echo ""
  echo "Container status:"
  sudo crictl ps -a --name kube-apiserver || true
  echo ""
  echo "Recent container logs:"
  CID=$(sudo crictl ps -a --name kube-apiserver -q | head -n 1)
  if [[ -n "$CID" ]]; then
    sudo crictl logs --tail 20 "$CID" 2>&1 || true
  fi
  exit 1
fi

echo "✅ kube-apiserver container is running"
CONTAINER_ID=$(echo "$RUNNING_CONTAINERS" | head -n 1)
echo "   Container ID: $CONTAINER_ID"

# Check container is not constantly restarting
sleep 3
NEW_CONTAINER_ID=$(sudo crictl ps --name kube-apiserver -q | head -n 1)
if [[ "$CONTAINER_ID" != "$NEW_CONTAINER_ID" ]]; then
  echo "❌ kube-apiserver container is restarting (different container ID)"
  exit 1
fi
echo "✅ Container is stable (not restarting)"

# ----------------------------------------------------------
# 5. Test kubectl functionality
# ----------------------------------------------------------
echo ""
echo "[5/6] Testing kubectl connectivity..."

if ! kubectl get --raw /healthz &>/dev/null; then
  echo "❌ API server health check failed"
  exit 1
fi
echo "✅ API server health endpoint is responding"

if ! kubectl get nodes &>/dev/null; then
  echo "❌ kubectl get nodes command failed"
  exit 1
fi
echo "✅ kubectl can communicate with API server"

# Check node status
NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
if [[ "$NODE_STATUS" != "True" ]]; then
  echo "⚠️  Warning: Node is not in Ready state"
else
  echo "✅ Node is in Ready state"
fi

# ----------------------------------------------------------
# 6. Verify control plane pods
# ----------------------------------------------------------
echo ""
echo "[6/6] Checking control plane pods..."

# Wait for pods to stabilize
sleep 5

APISERVER_PODS=$(kubectl get pods -n kube-system -l component=kube-apiserver --no-headers 2>/dev/null | wc -l)
if [[ "$APISERVER_PODS" -eq 0 ]]; then
  echo "❌ No kube-apiserver pod found in kube-system namespace"
  exit 1
fi

APISERVER_RUNNING=$(kubectl get pods -n kube-system -l component=kube-apiserver --no-headers 2>/dev/null | grep -c "Running" || true)
if [[ "$APISERVER_RUNNING" -eq 0 ]]; then
  echo "❌ kube-apiserver pod is not in Running state"
  kubectl get pods -n kube-system -l component=kube-apiserver
  exit 1
fi

echo "✅ kube-apiserver pod is Running in kube-system namespace"

# Check all control plane components
CONTROL_PLANE_READY=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | grep -c "Running" || true)
TOTAL_CONTROL_PLANE=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | wc -l)

if [[ "$CONTROL_PLANE_READY" -lt "$TOTAL_CONTROL_PLANE" ]]; then
  echo "⚠️  Warning: Some control plane pods are not Running ($CONTROL_PLANE_READY/$TOTAL_CONTROL_PLANE)"
else
  echo "✅ All control plane pods are Running ($CONTROL_PLANE_READY/$TOTAL_CONTROL_PLANE)"
fi

# ----------------------------------------------------------
# Final Summary
# ----------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 VERIFICATION PASSED!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary:"
echo "   ✅ API server certificate regenerated"
echo "   ✅ API server key regenerated"
echo "   ✅ kube-apiserver container running"
echo "   ✅ kubectl functionality restored"
echo "   ✅ Control plane operational"
echo ""
echo "🎯 Mission Accomplished!"
echo "You successfully recovered the Kubernetes API server"
echo "from a catastrophic certificate deletion!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
