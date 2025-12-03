#!/bin/bash
set -euo pipefail

GATEWAY_NS="anime-gtw"
PROD_NS="prod"
GATEWAY_NAME="anime-app-gateway"
HTTPROUTE_NAME="anime-api-httproute"
HOSTNAME="anime.streaming.io"
PRIMARY_SVC="api-v1"
MIRROR_SVC="api-v2"

echo "🔍 Verifying Gateway API Traffic Mirroring configuration..."
echo ""

# Check if HTTPRoute exists
if ! kubectl get httproute "${HTTPROUTE_NAME}" -n "${PROD_NS}" &>/dev/null; then
  echo "❌ HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${PROD_NS}'"
  echo "💡 Hint: Create the HTTPRoute with traffic mirroring configuration"
  exit 1
fi
echo "✅ HTTPRoute '${HTTPROUTE_NAME}' exists in namespace '${PROD_NS}'"

# Verify HTTPRoute parent reference
PARENT_GATEWAY=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${PROD_NS}" -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null || echo "")
PARENT_NS=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${PROD_NS}" -o jsonpath='{.spec.parentRefs[0].namespace}' 2>/dev/null || echo "")

if [[ "${PARENT_GATEWAY}" != "${GATEWAY_NAME}" ]]; then
  echo "❌ HTTPRoute parent gateway is '${PARENT_GATEWAY}', expected '${GATEWAY_NAME}'"
  exit 1
fi
echo "✅ HTTPRoute references correct Gateway: ${GATEWAY_NAME}"

if [[ "${PARENT_NS}" != "${GATEWAY_NS}" ]]; then
  echo "❌ Parent gateway namespace is '${PARENT_NS}', expected '${GATEWAY_NS}'"
  exit 1
fi
echo "✅ HTTPRoute references Gateway in correct namespace: ${GATEWAY_NS}"

# Verify hostname
ROUTE_HOSTNAME=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${PROD_NS}" -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null || echo "")
if [[ "${ROUTE_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ HTTPRoute hostname is '${ROUTE_HOSTNAME}', expected '${HOSTNAME}'"
  exit 1
fi
echo "✅ HTTPRoute hostname: ${HOSTNAME}"

# Get HTTPRoute JSON for detailed verification
ROUTE_JSON=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${PROD_NS}" -o json)

# Verify primary backend (api-v1)
echo ""
echo "🔍 Verifying primary backend configuration..."
PRIMARY_BACKEND=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[0].name' 2>/dev/null || echo "")
PRIMARY_PORT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[0].port' 2>/dev/null || echo "")

if [[ "${PRIMARY_BACKEND}" != "${PRIMARY_SVC}" ]]; then
  echo "❌ Primary backend service is '${PRIMARY_BACKEND}', expected '${PRIMARY_SVC}'"
  exit 1
fi
echo "✅ Primary backend service: ${PRIMARY_SVC}"

if [[ "${PRIMARY_PORT}" != "80" ]]; then
  echo "❌ Primary backend port is '${PRIMARY_PORT}', expected '80'"
  exit 1
fi
echo "✅ Primary backend port: 80"

# Verify path configuration
PATH_TYPE=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].matches[0].path.type' 2>/dev/null || echo "")
PATH_VALUE=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].matches[0].path.value' 2>/dev/null || echo "")

if [[ "${PATH_TYPE}" != "PathPrefix" ]]; then
  echo "❌ Path type is '${PATH_TYPE}', expected 'PathPrefix'"
  exit 1
fi
echo "✅ Path match type: PathPrefix"

if [[ "${PATH_VALUE}" != "/" ]]; then
  echo "❌ Path value is '${PATH_VALUE}', expected '/'"
  exit 1
fi
echo "✅ Path value: /"

# Verify traffic mirroring filter
echo ""
echo "🔍 Verifying traffic mirroring configuration..."

FILTER_TYPE=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].filters[0].type' 2>/dev/null || echo "")
if [[ "${FILTER_TYPE}" != "RequestMirror" ]]; then
  echo "❌ Filter type is '${FILTER_TYPE}', expected 'RequestMirror'"
  echo "💡 Hint: Add a RequestMirror filter to mirror traffic to api-v2"
  exit 1
fi
echo "✅ Filter type: RequestMirror"

# Verify mirror backend
MIRROR_BACKEND=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].filters[0].requestMirror.backendRef.name' 2>/dev/null || echo "")
MIRROR_PORT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].filters[0].requestMirror.backendRef.port' 2>/dev/null || echo "")
MIRROR_WEIGHT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].filters[0].requestMirror.backendRef.weight' 2>/dev/null || echo "")

if [[ "${MIRROR_BACKEND}" != "${MIRROR_SVC}" ]]; then
  echo "❌ Mirror backend service is '${MIRROR_BACKEND}', expected '${MIRROR_SVC}'"
  exit 1
fi
echo "✅ Mirror backend service: ${MIRROR_SVC}"

if [[ "${MIRROR_PORT}" != "80" ]]; then
  echo "❌ Mirror backend port is '${MIRROR_PORT}', expected '80'"
  exit 1
fi
echo "✅ Mirror backend port: 80"

if [[ "${MIRROR_WEIGHT}" != "10" ]]; then
  echo "❌ Mirror weight is '${MIRROR_WEIGHT}', expected '10' (10% of traffic)"
  echo "💡 Hint: Set weight to 10 to mirror 10% of traffic"
  exit 1
fi
echo "✅ Mirror weight: 10 (10% of traffic mirrored)"

# Check HTTPRoute status
echo ""
echo "🔍 Checking HTTPRoute status..."
ROUTE_STATUS=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${PROD_NS}" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "Unknown")

if [[ "${ROUTE_STATUS}" == "True" ]]; then
  echo "✅ HTTPRoute is Accepted and ready"
else
  echo "⚠️  HTTPRoute status: ${ROUTE_STATUS}"
  echo "💡 The HTTPRoute may still be initializing. Check: kubectl describe httproute ${HTTPROUTE_NAME} -n ${PROD_NS}"
fi

# Check if services exist and are ready
echo ""
echo "🔍 Verifying backend services..."

# Check api-v1
if ! kubectl get svc "${PRIMARY_SVC}" -n "${PROD_NS}" &>/dev/null; then
  echo "❌ Service '${PRIMARY_SVC}' not found in namespace '${PROD_NS}'"
  exit 1
fi
echo "✅ Service '${PRIMARY_SVC}' exists"

API_V1_ENDPOINTS=$(kubectl get endpoints "${PRIMARY_SVC}" -n "${PROD_NS}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
if [[ -z "${API_V1_ENDPOINTS}" ]] || [[ "${API_V1_ENDPOINTS}" == "null" ]]; then
  echo "⚠️  Warning: Service '${PRIMARY_SVC}' has no ready endpoints"
else
  echo "✅ Service '${PRIMARY_SVC}' has ready endpoints"
fi

# Check api-v2
if ! kubectl get svc "${MIRROR_SVC}" -n "${PROD_NS}" &>/dev/null; then
  echo "❌ Service '${MIRROR_SVC}' not found in namespace '${PROD_NS}'"
  exit 1
fi
echo "✅ Service '${MIRROR_SVC}' exists"

API_V2_ENDPOINTS=$(kubectl get endpoints "${MIRROR_SVC}" -n "${PROD_NS}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
if [[ -z "${API_V2_ENDPOINTS}" ]] || [[ "${API_V2_ENDPOINTS}" == "null" ]]; then
  echo "⚠️  Warning: Service '${MIRROR_SVC}' has no ready endpoints"
else
  echo "✅ Service '${MIRROR_SVC}' has ready endpoints"
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
  echo "🧪 Testing API connectivity..."
  
  # Test endpoint
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${HOSTNAME}/" 2>/dev/null || echo "000")
  
  if [[ "${HTTP_CODE}" == "200" ]]; then
    echo "✅ API endpoint is accessible (HTTP ${HTTP_CODE})"
    
    # Verify we get api-v1 responses
    API_VERSION=$(curl -s --max-time 5 "http://${HOSTNAME}/" 2>/dev/null | jq -r '.api_version' 2>/dev/null || echo "unknown")
    if [[ "${API_VERSION}" == "v1" ]]; then
      echo "✅ Users receive responses from api-v1 (primary backend)"
    else
      echo "⚠️  Unexpected API version in response: ${API_VERSION}"
    fi
  else
    echo "⚠️  Could not access API endpoint (HTTP ${HTTP_CODE})"
    echo "💡 Gateway may still be initializing. Wait a moment and try: curl http://${HOSTNAME}/"
  fi
fi

# Summary
echo ""
echo "🎉 Traffic Mirroring verification complete!"
echo ""
echo "📊 Configuration Summary:"
echo "   • HTTPRoute: ${HTTPROUTE_NAME} (${PROD_NS})"
echo "   • Gateway: ${GATEWAY_NAME} (${GATEWAY_NS})"
echo "   • Hostname: ${HOSTNAME}"
echo "   • Primary Backend: ${PRIMARY_SVC} (100% of user responses)"
echo "   • Mirror Backend: ${MIRROR_SVC} (10% of traffic mirrored)"
echo "   • Path: / (PathPrefix)"
echo ""
echo "✅ Traffic mirroring is correctly configured!"
echo "💡 Users receive responses only from ${PRIMARY_SVC}"
echo "💡 ${MIRROR_SVC} receives ~10% of mirrored requests for testing"
echo ""
exit 0
