#!/bin/bash
set -euo pipefail

GTW_NS="jp-bullet-train-gtw"
APP_NS="jp-bullet-train-app-prod"
GATEWAY_NAME="bullet-train-gateway"
HTTPROUTE_NAME="bullet-train-route"
HOSTNAME="bullet.train.io"
GATEWAY_IP="192.168.1.240"


echo "🔍 Verifying Gateway API configuration for Japan Bullet Train System..."
echo ""

# Check if gateway namespace exists
if ! kubectl get ns "${GTW_NS}" &>/dev/null; then
  echo "❌ Namespace '${GTW_NS}' not found"
  exit 1
fi

# Check if Gateway exists
if ! kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" &>/dev/null; then
  echo "❌ Gateway '${GATEWAY_NAME}' not found in namespace '${GTW_NS}'"
  echo "💡 Hint: Create the Gateway using the provided YAML structure"
  exit 1
fi
echo "✅ Gateway '${GATEWAY_NAME}' exists"

# Verify Gateway configuration
GATEWAY_CLASS=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.gatewayClassName}')
if [[ "${GATEWAY_CLASS}" != "nginx" ]]; then
  echo "❌ Gateway gatewayClassName is '${GATEWAY_CLASS}', expected 'nginx'"
  exit 1
fi
echo "✅ Gateway uses correct GatewayClass: nginx"

# Check listener configuration
LISTENER_PROTOCOL=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.listeners[0].protocol}')
LISTENER_PORT=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.listeners[0].port}')
LISTENER_HOSTNAME=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.listeners[0].hostname}')

if [[ "${LISTENER_PROTOCOL}" != "HTTPS" ]]; then
  echo "❌ Listener protocol is '${LISTENER_PROTOCOL}', expected 'HTTPS'"
  exit 1
fi
echo "✅ Listener protocol: HTTPS"

if [[ "${LISTENER_PORT}" != "443" ]]; then
  echo "❌ Listener port is '${LISTENER_PORT}', expected '443'"
  exit 1
fi
echo "✅ Listener port: 443"

if [[ "${LISTENER_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ Listener hostname is '${LISTENER_HOSTNAME}', expected '${HOSTNAME}'"
  exit 1
fi
echo "✅ Listener hostname: ${HOSTNAME}"

# Check TLS configuration
TLS_MODE=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.listeners[0].tls.mode}')
TLS_SECRET=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}')

if [[ "${TLS_MODE}" != "Terminate" ]]; then
  echo "❌ TLS mode is '${TLS_MODE}', expected 'Terminate'"
  exit 1
fi
echo "✅ TLS mode: Terminate"

if [[ "${TLS_SECRET}" != "bullet-train-tls" ]]; then
  echo "❌ TLS certificate reference is '${TLS_SECRET}', expected 'bullet-train-tls'"
  exit 1
fi
echo "✅ TLS certificate: bullet-train-tls"

# Check if HTTPRoute exists
if ! kubectl get httproute "${HTTPROUTE_NAME}" -n "${GTW_NS}" &>/dev/null; then
  echo "❌ HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${GTW_NS}'"
  echo "💡 Hint: Create the HTTPRoute with path-based routing to the three services"
  exit 1
fi
echo "✅ HTTPRoute '${HTTPROUTE_NAME}' exists"

# Verify HTTPRoute parent reference
PARENT_GATEWAY=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.parentRefs[0].name}')
if [[ "${PARENT_GATEWAY}" != "${GATEWAY_NAME}" ]]; then
  echo "❌ HTTPRoute parent gateway is '${PARENT_GATEWAY}', expected '${GATEWAY_NAME}'"
  exit 1
fi
echo "✅ HTTPRoute references correct Gateway"

# Verify HTTPRoute hostname
ROUTE_HOSTNAME=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${GTW_NS}" -o jsonpath='{.spec.hostnames[0]}')
if [[ "${ROUTE_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ HTTPRoute hostname is '${ROUTE_HOSTNAME}', expected '${HOSTNAME}'"
  exit 1
fi
echo "✅ HTTPRoute hostname: ${HOSTNAME}"

# Verify path-based routing rules
echo ""
echo "🔍 Verifying HTTPRoute rules..."

# Get all rules
RULES_JSON=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${GTW_NS}" -o json)

# Check for /available path
AVAILABLE_PATH=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/available") | .matches[0].path.value' 2>/dev/null || true)
AVAILABLE_SVC=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/available") | .backendRefs[0].name' 2>/dev/null || true)
AVAILABLE_NS=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/available") | .backendRefs[0].namespace' 2>/dev/null || true)

if [[ "${AVAILABLE_PATH}" != "/available" ]] || [[ "${AVAILABLE_SVC}" != "available" ]] || [[ "${AVAILABLE_NS}" != "${APP_NS}" ]]; then
  echo "❌ Missing or incorrect rule for /available → available service in ${APP_NS}"
  echo "   Found: path='${AVAILABLE_PATH}', service='${AVAILABLE_SVC}', namespace='${AVAILABLE_NS}'"
  exit 1
fi
echo "✅ Route configured: /available → available (${APP_NS})"

# Check for /books path
BOOKS_PATH=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/books") | .matches[0].path.value' 2>/dev/null || true)
BOOKS_SVC=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/books") | .backendRefs[0].name' 2>/dev/null || true)
BOOKS_NS=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/books") | .backendRefs[0].namespace' 2>/dev/null || true)

if [[ "${BOOKS_PATH}" != "/books" ]] || [[ "${BOOKS_SVC}" != "books" ]] || [[ "${BOOKS_NS}" != "${APP_NS}" ]]; then
  echo "❌ Missing or incorrect rule for /books → books service in ${APP_NS}"
  echo "   Found: path='${BOOKS_PATH}', service='${BOOKS_SVC}', namespace='${BOOKS_NS}'"
  exit 1
fi
echo "✅ Route configured: /books → books (${APP_NS})"

# Check for /travellers path
TRAVELLERS_PATH=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/travellers") | .matches[0].path.value' 2>/dev/null || true)
TRAVELLERS_SVC=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/travellers") | .backendRefs[0].name' 2>/dev/null || true)
TRAVELLERS_NS=$(echo "${RULES_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/travellers") | .backendRefs[0].namespace' 2>/dev/null || true)

if [[ "${TRAVELLERS_PATH}" != "/travellers" ]] || [[ "${TRAVELLERS_SVC}" != "travellers" ]] || [[ "${TRAVELLERS_NS}" != "${APP_NS}" ]]; then
  echo "❌ Missing or incorrect rule for /travellers → travellers service in ${APP_NS}"
  echo "   Found: path='${TRAVELLERS_PATH}', service='${TRAVELLERS_SVC}', namespace='${TRAVELLERS_NS}'"
  exit 1
fi
echo "✅ Route configured: /travellers → travellers (${APP_NS})"

# Check if Gateway IP is provided through environment variable
if [[ -z "${GATEWAY_IP}" ]]; then
  echo ""
  echo "⚠️  Warning: GATEWAY_IP environment variable is not set"
  echo "💡 Hint: Set it using:"
  echo "   export GATEWAY_IP=<your-loadbalancer-ip>"
else
  echo ""
  echo "✅ Gateway IP detected from environment: ${GATEWAY_IP}"
  
  # Check if /etc/hosts contains the entry
  if grep -q "${HOSTNAME}" /etc/hosts; then
    echo "✅ /etc/hosts configured for ${HOSTNAME}"
    
    # Verify the IP matches
    HOSTS_IP=$(grep "${HOSTNAME}" /etc/hosts | awk '{print $1}' | head -n1)
    if [[ "${HOSTS_IP}" == "${GATEWAY_IP}" ]]; then
      echo "✅ /etc/hosts IP matches Gateway IP"
    else
      echo "⚠️  Warning: /etc/hosts IP (${HOSTS_IP}) differs from Gateway IP (${GATEWAY_IP})"
    fi
  else
    echo "⚠️  Warning: ${HOSTNAME} not found in /etc/hosts"
    echo "💡 Hint: Add entry using:"
    echo "   echo '${GATEWAY_IP} ${HOSTNAME}' | sudo tee -a /etc/hosts"
  fi
fi

# Check Gateway status
echo ""
echo "🔍 Checking Gateway status..."
GATEWAY_STATUS=$(kubectl get gateway "${GATEWAY_NAME}" -n "${GTW_NS}" -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Unknown")

if [[ "${GATEWAY_STATUS}" == "True" ]]; then
  echo "✅ Gateway is Programmed and ready"
else
  echo "⚠️  Gateway status: ${GATEWAY_STATUS}"
  echo "💡 The Gateway may still be initializing. Wait a few moments and check: kubectl get gateway -n ${GTW_NS}"
fi

# Try to test connectivity (if /etc/hosts is configured)
if grep -q "${HOSTNAME}" /etc/hosts && command -v curl &>/dev/null; then
  echo ""
  echo "🧪 Testing connectivity..."
  
  # Test /available
  if curl -sk --max-time 5 "https://${HOSTNAME}/available" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "200"; then
    echo "✅ Endpoint /available is accessible"
  else
    echo "⚠️  Could not access /available endpoint (Gateway may still be initializing)"
  fi
  
  # Test /books
  if curl -sk --max-time 5 "https://${HOSTNAME}/books" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "200"; then
    echo "✅ Endpoint /books is accessible"
  else
    echo "⚠️  Could not access /books endpoint (Gateway may still be initializing)"
  fi
  
  # Test /travellers
  if curl -sk --max-time 5 "https://${HOSTNAME}/travellers" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "200"; then
    echo "✅ Endpoint /travellers is accessible"
  else
    echo "⚠️  Could not access /travellers endpoint (Gateway may still be initializing)"
  fi
fi

echo ""
echo "🎉 Gateway API configuration verification complete!"
echo ""
echo "📊 Summary:"
echo "   • Gateway: ${GATEWAY_NAME} (${GTW_NS})"
echo "   • HTTPRoute: ${HTTPROUTE_NAME} (${GTW_NS})"
echo "   • Hostname: ${HOSTNAME}"
echo "   • Routes: /available, /books, /travellers"
echo "   • Target Services: available, books, travellers (${APP_NS})"
echo ""
exit 0
