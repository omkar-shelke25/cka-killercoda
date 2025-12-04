#!/bin/bash
set -euo pipefail

GATEWAY_NS="str-gtw"
APP_NS="hawkins"
GATEWAY_NAME="stranger-gw"
HTTPROUTE_NAME="stranger-canary-route"
HOSTNAME="api.stranger.things"
SVC_V1="stv-v1"
SVC_V2="stv-v2"
PORT="8080"
PATH="/recommendations"
WEIGHT_V1="90"
WEIGHT_V2="10"

echo "🔍 Verifying CKA Task: Gateway API Canary Deployment..."
echo ""

# Check if manifest file exists
if [[ ! -f "/root/st-canary.yaml" ]]; then
  echo "❌ File not found: /root/st-canary.yaml"
  echo "💡 Hint: Save your HTTPRoute manifest to /root/st-canary.yaml"
  exit 1
fi
echo "✅ Manifest file exists: /root/st-canary.yaml"

# Check if HTTPRoute exists
if ! kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" &>/dev/null; then
  echo "❌ HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${APP_NS}'"
  echo "💡 Hint: Apply your manifest with: kubectl apply -f /root/st-canary.yaml"
  exit 1
fi
echo "✅ HTTPRoute '${HTTPROUTE_NAME}' exists in namespace '${APP_NS}'"

# Verify HTTPRoute parent reference
PARENT_GATEWAY=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null || echo "")
PARENT_NS=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" -o jsonpath='{.spec.parentRefs[0].namespace}' 2>/dev/null || echo "")

if [[ "${PARENT_GATEWAY}" != "${GATEWAY_NAME}" ]]; then
  echo "❌ HTTPRoute parent gateway is '${PARENT_GATEWAY}', expected '${GATEWAY_NAME}'"
  echo "💡 Hint: Use parentRefs with name: ${GATEWAY_NAME}"
  exit 1
fi
echo "✅ HTTPRoute references correct Gateway: ${GATEWAY_NAME}"

if [[ "${PARENT_NS}" != "${GATEWAY_NS}" ]]; then
  echo "❌ Parent gateway namespace is '${PARENT_NS}', expected '${GATEWAY_NS}'"
  echo "💡 Hint: Specify namespace: ${GATEWAY_NS} in parentRefs"
  exit 1
fi
echo "✅ HTTPRoute references Gateway in correct namespace: ${GATEWAY_NS}"

# Verify hostname
ROUTE_HOSTNAME=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null || echo "")
if [[ "${ROUTE_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ HTTPRoute hostname is '${ROUTE_HOSTNAME}', expected '${HOSTNAME}'"
  echo "💡 Hint: Set hostnames to: ${HOSTNAME}"
  exit 1
fi
echo "✅ HTTPRoute hostname: ${HOSTNAME}"

# Get HTTPRoute JSON for detailed verification
ROUTE_JSON=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" -o json)

# Verify path configuration
PATH_TYPE=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].matches[0].path.type' 2>/dev/null || echo "")
PATH_VALUE=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].matches[0].path.value' 2>/dev/null || echo "")

if [[ "${PATH_TYPE}" != "PathPrefix" ]]; then
  echo "❌ Path type is '${PATH_TYPE}', expected 'PathPrefix'"
  echo "💡 Hint: Use type: PathPrefix in path matching"
  exit 1
fi
echo "✅ Path match type: PathPrefix"

if [[ "${PATH_VALUE}" != "${PATH}" ]]; then
  echo "❌ Path value is '${PATH_VALUE}', expected '${PATH}'"
  echo "💡 Hint: Set path value to: ${PATH}"
  exit 1
fi
echo "✅ Path value: ${PATH}"

# Verify backend references and weights
echo ""
echo "🔍 Verifying canary traffic split (90/10)..."

# Check number of backend refs
BACKEND_COUNT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs | length' 2>/dev/null || echo "0")
if [[ "${BACKEND_COUNT}" != "2" ]]; then
  echo "❌ Found ${BACKEND_COUNT} backend references, expected 2"
  echo "💡 Hint: You need two backendRefs - one for stv-v1 and one for stv-v2"
  exit 1
fi
echo "✅ Found 2 backend references"

# Get backend details
BACKEND_1_NAME=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[0].name' 2>/dev/null || echo "")
BACKEND_1_PORT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[0].port' 2>/dev/null || echo "")
BACKEND_1_WEIGHT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[0].weight' 2>/dev/null || echo "")

BACKEND_2_NAME=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[1].name' 2>/dev/null || echo "")
BACKEND_2_PORT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[1].port' 2>/dev/null || echo "")
BACKEND_2_WEIGHT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[1].weight' 2>/dev/null || echo "")

# Determine which is v1 and which is v2
V1_WEIGHT=""
V2_WEIGHT=""
V1_PORT=""
V2_PORT=""

if [[ "${BACKEND_1_NAME}" == "${SVC_V1}" ]]; then
  V1_WEIGHT="${BACKEND_1_WEIGHT}"
  V1_PORT="${BACKEND_1_PORT}"
  if [[ "${BACKEND_2_NAME}" == "${SVC_V2}" ]]; then
    V2_WEIGHT="${BACKEND_2_WEIGHT}"
    V2_PORT="${BACKEND_2_PORT}"
  else
    echo "❌ Second backend is '${BACKEND_2_NAME}', expected '${SVC_V2}'"
    exit 1
  fi
elif [[ "${BACKEND_1_NAME}" == "${SVC_V2}" ]]; then
  V2_WEIGHT="${BACKEND_1_WEIGHT}"
  V2_PORT="${BACKEND_1_PORT}"
  if [[ "${BACKEND_2_NAME}" == "${SVC_V1}" ]]; then
    V1_WEIGHT="${BACKEND_2_WEIGHT}"
    V1_PORT="${BACKEND_2_PORT}"
  else
    echo "❌ Second backend is '${BACKEND_2_NAME}', expected '${SVC_V1}'"
    exit 1
  fi
else
  echo "❌ Backend '${BACKEND_1_NAME}' not recognized. Expected '${SVC_V1}' or '${SVC_V2}'"
  exit 1
fi

# Verify stv-v1 configuration
if [[ "${V1_PORT}" != "${PORT}" ]]; then
  echo "❌ Service ${SVC_V1} port is '${V1_PORT}', expected '${PORT}'"
  echo "💡 Hint: Both services listen on port 8080"
  exit 1
fi
echo "✅ Service ${SVC_V1} configured with port ${PORT}"

if [[ "${V1_WEIGHT}" != "${WEIGHT_V1}" ]]; then
  echo "❌ Service ${SVC_V1} weight is '${V1_WEIGHT}', expected '${WEIGHT_V1}'"
  echo "💡 Hint: stv-v1 (stable) should have weight 90"
  exit 1
fi
echo "✅ Service ${SVC_V1} configured with weight ${WEIGHT_V1}"

# Verify stv-v2 configuration
if [[ "${V2_PORT}" != "${PORT}" ]]; then
  echo "❌ Service ${SVC_V2} port is '${V2_PORT}', expected '${PORT}'"
  echo "💡 Hint: Both services listen on port 8080"
  exit 1
fi
echo "✅ Service ${SVC_V2} configured with port ${PORT}"

if [[ "${V2_WEIGHT}" != "${WEIGHT_V2}" ]]; then
  echo "❌ Service ${SVC_V2} weight is '${V2_WEIGHT}', expected '${WEIGHT_V2}'"
  echo "💡 Hint: stv-v2 (experimental) should have weight 10"
  exit 1
fi
echo "✅ Service ${SVC_V2} configured with weight ${WEIGHT_V2}"

# Calculate traffic split percentage
TOTAL_WEIGHT=$((WEIGHT_V1 + WEIGHT_V2))
V1_PERCENTAGE=$((WEIGHT_V1 * 100 / TOTAL_WEIGHT))
V2_PERCENTAGE=$((WEIGHT_V2 * 100 / TOTAL_WEIGHT))

echo ""
echo "📊 Canary Traffic Split Configuration:"
echo "   • ${SVC_V1} (stable): ${V1_PERCENTAGE}% of traffic"
echo "   • ${SVC_V2} (experimental): ${V2_PERCENTAGE}% of traffic"

# Check HTTPRoute status
echo ""
echo "🔍 Checking HTTPRoute status..."
ROUTE_STATUS=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "Unknown")

if [[ "${ROUTE_STATUS}" == "True" ]]; then
  echo "✅ HTTPRoute is Accepted by Gateway"
else
  echo "⚠️  HTTPRoute status: ${ROUTE_STATUS}"
  echo "💡 The HTTPRoute may still be processing. Check: kubectl describe httproute ${HTTPROUTE_NAME} -n ${APP_NS}"
fi

# Check if services exist and are ready
echo ""
echo "🔍 Verifying backend services..."

# Check stv-v1
if ! kubectl get svc "${SVC_V1}" -n "${APP_NS}" &>/dev/null; then
  echo "❌ Service '${SVC_V1}' not found in namespace '${APP_NS}'"
  exit 1
fi

V1_ENDPOINTS=$(kubectl get endpoints "${SVC_V1}" -n "${APP_NS}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
if [[ -z "${V1_ENDPOINTS}" ]] || [[ "${V1_ENDPOINTS}" == "null" ]]; then
  echo "⚠️  Warning: Service '${SVC_V1}' has no ready endpoints"
else
  echo "✅ Service '${SVC_V1}' is ready with endpoints"
fi

# Check stv-v2
if ! kubectl get svc "${SVC_V2}" -n "${APP_NS}" &>/dev/null; then
  echo "❌ Service '${SVC_V2}' not found in namespace '${APP_NS}'"
  exit 1
fi

V2_ENDPOINTS=$(kubectl get endpoints "${SVC_V2}" -n "${APP_NS}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
if [[ -z "${V2_ENDPOINTS}" ]] || [[ "${V2_ENDPOINTS}" == "null" ]]; then
  echo "⚠️  Warning: Service '${SVC_V2}' has no ready endpoints"
else
  echo "✅ Service '${SVC_V2}' is ready with endpoints"
fi

# Check Gateway status
echo ""
echo "🔍 Checking Gateway status..."
if kubectl get gateway "${GATEWAY_NAME}" -n "${GATEWAY_NS}" &>/dev/null; then
  GATEWAY_STATUS=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GATEWAY_NS}" -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Unknown")
  if [[ "${GATEWAY_STATUS}" == "True" ]]; then
    echo "✅ Gateway '${GATEWAY_NAME}' is Programmed and ready"
  else
    echo "⚠️  Gateway status: ${GATEWAY_STATUS}"
  fi
else
  echo "⚠️  Gateway '${GATEWAY_NAME}' not found in namespace '${GATEWAY_NS}'"
fi

# Check /etc/hosts configuration
echo ""
echo "🔍 Checking DNS configuration..."
if grep -q "${HOSTNAME}" /etc/hosts 2>/dev/null; then
  echo "✅ /etc/hosts configured for ${HOSTNAME}"
  HOSTS_IP=$(grep "${HOSTNAME}" /etc/hosts | awk '{print $1}' | head -n1)
  echo "   Configured IP: ${HOSTS_IP}"
else
  echo "ℹ️  ${HOSTNAME} not found in /etc/hosts"
  echo "💡 To test locally, add: echo '192.168.1.240 ${HOSTNAME}' | sudo tee -a /etc/hosts"
fi

# Try to test connectivity if possible
if grep -q "${HOSTNAME}" /etc/hosts 2>/dev/null && command -v curl &>/dev/null; then
  echo ""
  echo "🧪 Testing canary deployment traffic distribution..."
  
  # Make 20 test requests
  V1_COUNT=0
  V2_COUNT=0
  
  for i in {1..20}; do
    VERSION=$(curl -s --max-time 2 "http://${HOSTNAME}${PATH}" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "error")
    if [[ "${VERSION}" == "v1" ]]; then
      ((V1_COUNT++))
    elif [[ "${VERSION}" == "v2" ]]; then
      ((V2_COUNT++))
    fi
  done
  
  TOTAL_REQUESTS=$((V1_COUNT + V2_COUNT))
  
  if [[ ${TOTAL_REQUESTS} -gt 0 ]]; then
    V1_PERCENT=$((V1_COUNT * 100 / TOTAL_REQUESTS))
    V2_PERCENT=$((V2_COUNT * 100 / TOTAL_REQUESTS))
    
    echo "   📊 Traffic Distribution (20 requests):"
    echo "      • v1 (stable): ${V1_COUNT} requests (${V1_PERCENT}%)"
    echo "      • v2 (experimental): ${V2_COUNT} requests (${V2_PERCENT}%)"
    
    # Check if distribution is approximately correct (within reasonable margin)
    if [[ ${V1_COUNT} -ge 15 ]] && [[ ${V1_COUNT} -le 20 ]]; then
      if [[ ${V2_COUNT} -ge 0 ]] && [[ ${V2_COUNT} -le 5 ]]; then
        echo "   ✅ Traffic distribution matches expected 90/10 split"
      else
        echo "   ⚠️  Traffic to v2 seems higher than expected 10%"
      fi
    else
      echo "   ⚠️  Traffic distribution may need more requests for accurate measurement"
    fi
  else
    echo "   ⚠️  Could not test traffic distribution"
    echo "   💡 Gateway may still be initializing. Try: curl http://${HOSTNAME}${PATH}"
  fi
fi

# Final summary
echo ""
echo "🎉 Canary Deployment verification complete!"
echo ""
echo "📊 Configuration Summary:"
echo "   • HTTPRoute: ${HTTPROUTE_NAME} (${APP_NS})"
echo "   • Gateway: ${GATEWAY_NAME} (${GATEWAY_NS})"
echo "   • Hostname: ${HOSTNAME}"
echo "   • Path: ${PATH}"
echo "   • Traffic Split: ${V1_PERCENTAGE}% → ${SVC_V1}, ${V2_PERCENTAGE}% → ${SVC_V2}"
echo "   • Manifest: /root/st-canary.yaml"
echo ""
echo "✅ CKA Task completed successfully!"
echo "🔬 Hawkins Lab approves: Canary deployment configured correctly!"
echo "⚡ The Upside Down Mode is being safely tested with ${V2_PERCENTAGE}% of traffic!"
echo ""
exit 0
