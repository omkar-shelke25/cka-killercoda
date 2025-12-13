#!/bin/bash
set -euo pipefail

MANIFEST_PATH="/etc/kubernetes/manifests/kube-apiserver.yaml"
CORRECT_PORT="2379"
INCORRECT_PORT="2380"

echo "🔍 Verifying kube-apiserver etcd connection fix..."
echo ""

# Check if manifest exists
if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "❌ kube-apiserver manifest not found at ${MANIFEST_PATH}"
  exit 1
fi
echo "✅ kube-apiserver manifest exists"

# Check if the etcd port has been corrected
ETCD_SERVERS=$(grep "etcd-servers" "${MANIFEST_PATH}" || echo "")

if [[ -z "${ETCD_SERVERS}" ]]; then
  echo "❌ Could not find '--etcd-servers' configuration in manifest"
  exit 1
fi
echo "✅ Found etcd-servers configuration"

# Check if still using incorrect port 2380
if echo "${ETCD_SERVERS}" | grep -q ":${INCORRECT_PORT}"; then
  echo "❌ kube-apiserver is still configured to use port ${INCORRECT_PORT} (peer port)"
  echo "   Current configuration: ${ETCD_SERVERS}"
  echo "   You need to change port ${INCORRECT_PORT} to ${CORRECT_PORT}"
  exit 1
fi
echo "✅ No longer using incorrect peer port ${INCORRECT_PORT}"

# Check if using correct port 2379
if ! echo "${ETCD_SERVERS}" | grep -q ":${CORRECT_PORT}"; then
  echo "❌ kube-apiserver is not configured to use port ${CORRECT_PORT} (client port)"
  echo "   Current configuration: ${ETCD_SERVERS}"
  exit 1
fi
echo "✅ kube-apiserver configured to use correct client port ${CORRECT_PORT}"

# Display the current configuration
echo "   Current etcd-servers: $(echo ${ETCD_SERVERS} | awk '{print $2}')"

# Check if kube-apiserver container is running
echo ""
echo "🔍 Checking kube-apiserver container status..."
MAX_RETRIES=12
RETRY_COUNT=0
APISERVER_RUNNING=false

while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
  if sudo crictl ps | grep -q kube-apiserver; then
    APISERVER_RUNNING=true
    break
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; then
    echo "   Attempt ${RETRY_COUNT}/${MAX_RETRIES}: Container not running yet"
    sleep 3
  fi
done

if [[ "${APISERVER_RUNNING}" == "false" ]]; then
  echo "❌ kube-apiserver container is not running"
  echo ""
  echo "🔍 Checking recent containers:"
  sudo crictl ps -a | grep apiserver || echo "   No apiserver containers found"
  echo ""
  echo "🔍 Recent logs:"
  APISERVER_ID=$(sudo crictl ps -a | grep apiserver | awk '{print $1}' | head -n 1)
  if [[ -n "${APISERVER_ID}" ]]; then
    sudo crictl logs "${APISERVER_ID}" 2>&1 | tail -n 20
  fi
  exit 1
fi
echo "✅ kube-apiserver container is running"

# Test cluster connectivity
echo ""
echo "🔍 Testing cluster connectivity..."
MAX_RETRIES=10
RETRY_COUNT=0
CLUSTER_ACCESSIBLE=false

while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
  if kubectl get nodes &>/dev/null; then
    CLUSTER_ACCESSIBLE=true
    break
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; then
    echo "   Attempt ${RETRY_COUNT}/${MAX_RETRIES}: API not responding yet"
    sleep 2
  fi
done

if [[ "${CLUSTER_ACCESSIBLE}" == "false" ]]; then
  echo "❌ Cluster is not accessible via kubectl"
  echo ""
  echo "🔍 Testing kubectl:"
  kubectl get nodes 2>&1 || true
  echo ""
  echo "🔍 kube-apiserver logs:"
  APISERVER_ID=$(sudo crictl ps | grep kube-apiserver | awk '{print $1}')
  if [[ -n "${APISERVER_ID}" ]]; then
    sudo crictl logs "${APISERVER_ID}" 2>&1 | tail -n 30
  fi
  exit 1
fi
echo "✅ Cluster is accessible via kubectl"

# Test getting nodes
NODES_OUTPUT=$(kubectl get nodes 2>&1 || echo "")
if [[ -z "${NODES_OUTPUT}" ]] || echo "${NODES_OUTPUT}" | grep -q "error\|Error\|refused"; then
  echo "❌ Cannot retrieve node information"
  echo "   Output: ${NODES_OUTPUT}"
  exit 1
fi
echo "✅ Successfully retrieved node information"

# Count nodes
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
if [[ "${NODE_COUNT}" -gt 0 ]]; then
  echo "✅ Found ${NODE_COUNT} node(s) in the cluster"
else
  echo "⚠️  Warning: No nodes found (this might be normal for some test environments)"
fi

# Check kube-system pods
echo ""
echo "🔍 Checking control plane pods..."
KUBE_SYSTEM_PODS=$(kubectl get pods -n kube-system 2>/dev/null | grep -c "Running" || echo "0")
if [[ "${KUBE_SYSTEM_PODS}" -gt 0 ]]; then
  echo "✅ Found ${KUBE_SYSTEM_PODS} running pod(s) in kube-system namespace"
else
  echo "⚠️  Warning: No running pods found in kube-system (cluster may still be starting)"
fi

# Verify no errors in recent logs
echo ""
echo "🔍 Checking for connection errors in kube-apiserver logs..."
APISERVER_ID=$(sudo crictl ps | grep kube-apiserver | awk '{print $1}')
if [[ -n "${APISERVER_ID}" ]]; then
  RECENT_ERRORS=$(sudo crictl logs "${APISERVER_ID}" 2>&1 | tail -n 50 | grep -c "connection refused\|context deadline exceeded\|:2380" || echo "0")
  
  if [[ "${RECENT_ERRORS}" -gt 0 ]]; then
    echo "⚠️  Found ${RECENT_ERRORS} connection error(s) in recent logs"
    echo "   This might indicate the pod is still stabilizing"
  else
    echo "✅ No connection errors found in recent logs"
  fi
fi

echo ""
echo "🎉 Verification passed! kube-apiserver etcd connection fixed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ etcd-servers configuration corrected to use port ${CORRECT_PORT}"
echo "   ✅ kube-apiserver container is running"
echo "   ✅ Cluster is accessible via kubectl"
echo "   ✅ API server can communicate with etcd"
echo ""

# Display cluster status
echo "📋 Cluster Status:"
kubectl get nodes 2>/dev/null || echo "   Could not retrieve nodes"
echo ""
echo "📋 Control Plane Pods:"
kubectl get pods -n kube-system -l tier=control-plane 2>/dev/null || echo "   Could not retrieve control plane pods"

exit 0
