#!/bin/bash
set -euo pipefail

NAMESPACE="borderland"
GATEWAY_NAME="web-gateway"
HTTPROUTE_NAME="web-route"
HOSTNAME="gateway.web.k8s.local"
TLS_SECRET="web-tls"
SVC_GAMES="games-service"
SVC_PLAYERS="players-service"

echo "🎴 Verifying Migration Game - Checking Clear Conditions..."
echo ""

# Track success
ERRORS=0

# Check Gateway file exists
if [[ ! -f "/root/web-gateway.yaml" ]]; then
  echo "❌ File not found: /root/web-gateway.yaml"
  echo "💡 Hint: Save your Gateway manifest to /root/web-gateway.yaml"
  ((ERRORS++))
else
  echo "✅ Gateway manifest file exists"
fi

# Check HTTPRoute file exists
if [[ ! -f "/root/web-route.yaml" ]]; then
  echo "❌ File not found: /root/web-route.yaml"
  echo "💡 Hint: Save your HTTPRoute manifest to /root/web-route.yaml"
  ((ERRORS++))
else
  echo "✅ HTTPRoute manifest file exists"
fi

# Check if Gateway exists
if ! kubectl get gateway "${GATEWAY_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "❌ Gateway '${GATEWAY_NAME}' not found in namespace '${NAMESPACE}'"
  echo "💡 Hint: Apply your manifest: kubectl apply -f /root/web-gateway.yaml"
  ((ERRORS++))
  exit 1
else
  echo "✅ Gateway '${GATEWAY_NAME}' exists in namespace '${NAMESPACE}'"
fi

# Get Gateway JSON
GATEWAY_JSON=$(kubectl get gateway "${GATEWAY_NAME}" -n "${NAMESPACE}" -o json)

# Verify GatewayClassName
GATEWAY_CLASS=$(echo "${GATEWAY_JSON}" | jq -r '.spec.gatewayClassName')
if [[ "${GATEWAY_CLASS}" != "nginx" ]]; then
  echo "❌ Gateway gatewayClassName is '${GATEWAY_CLASS}', expected 'nginx'"
  ((ERRORS++))
else
  echo "✅ Gateway gatewayClassName: nginx"
fi

# Verify Listener exists
LISTENER_COUNT=$(echo "${GATEWAY_JSON}" | jq -r '.spec.listeners | length')
if [[ "${LISTENER_COUNT}" -eq 0 ]]; then
  echo "❌ No listeners found in Gateway"
  ((ERRORS++))
  exit 1
fi

# Verify Listener Protocol
LISTENER_PROTOCOL=$(echo "${GATEWAY_JSON}" | jq -r '.spec.listeners[0].protocol')
if [[ "${LISTENER_PROTOCOL}" != "HTTPS" ]]; then
  echo "❌ Listener protocol is '${LISTENER_PROTOCOL}', expected 'HTTPS'"
  echo "💡 Hint: Use protocol: HTTPS for TLS termination"
  ((ERRORS++))
else
  echo "✅ Listener protocol: HTTPS"
fi

# Verify Listener Port
LISTENER_PORT=$(echo "${GATEWAY_JSON}" | jq -r '.spec.listeners[0].port')
if [[ "${LISTENER_PORT}" != "443" ]]; then
  echo "❌ Listener port is '${LISTENER_PORT}', expected '443'"
  echo "💡 Hint: HTTPS uses port 443"
  ((ERRORS++))
else
  echo "✅ Listener port: 443"
fi

# Verify Listener Hostname
LISTENER_HOSTNAME=$(echo "${GATEWAY_JSON}" | jq -r '.spec.listeners[0].hostname')
if [[ "${LISTENER_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ Listener hostname is '${LISTENER_HOSTNAME}', expected '${HOSTNAME}'"
  ((ERRORS++))
else
  echo "✅ Listener hostname: ${HOSTNAME}"
fi

# Verify TLS Configuration
echo ""
echo "🔒 Checking TLS Configuration..."

TLS_MODE=$(echo "${GATEWAY_JSON}" | jq -r '.spec.listeners[0].tls.mode // empty')
if [[ "${TLS_MODE}" != "Terminate" ]]; then
  echo "❌ TLS mode is '${TLS_MODE}', expected 'Terminate'"
  echo "💡 Hint: Use tls.mode: Terminate for TLS termination at Gateway"
  ((ERRORS++))
else
  echo "✅ TLS mode: Terminate"
fi

TLS_CERT_NAME=$(echo "${GATEWAY_JSON}" | jq -r '.spec.listeners[0].tls.certificateRefs[0].name // empty')
if [[ "${TLS_CERT_NAME}" != "${TLS_SECRET}" ]]; then
  echo "❌ TLS certificate reference is '${TLS_CERT_NAME}', expected '${TLS_SECRET}'"
  echo "💡 Hint: Reference the existing secret: ${TLS_SECRET}"
  ((ERRORS++))
else
  echo "✅ TLS certificate reference: ${TLS_SECRET}"
fi

# Verify Gateway Status
echo ""
echo "🔍 Checking Gateway status..."
GATEWAY_PROGRAMMED=$(kubectl get gateway "${GATEWAY_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "Unknown")

if [[ "${GATEWAY_PROGRAMMED}" == "True" ]]; then
  echo "✅ Gateway is Programmed and ready"
else
  echo "⚠️  Gateway Programmed status: ${GATEWAY_PROGRAMMED}"
  echo "   The Gateway may still be initializing..."
fi

# Check HTTPRoute
echo ""
echo "🛣️  Checking HTTPRoute..."

if ! kubectl get httproute "${HTTPROUTE_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "❌ HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${NAMESPACE}'"
  echo "💡 Hint: Apply your manifest: kubectl apply -f /root/web-route.yaml"
  ((ERRORS++))
  exit 1
else
  echo "✅ HTTPRoute '${HTTPROUTE_NAME}' exists in namespace '${NAMESPACE}'"
fi

# Get HTTPRoute JSON
ROUTE_JSON=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${NAMESPACE}" -o json)

# Verify ParentRefs
PARENT_GATEWAY=$(echo "${ROUTE_JSON}" | jq -r '.spec.parentRefs[0].name // empty')
if [[ "${PARENT_GATEWAY}" != "${GATEWAY_NAME}" ]]; then
  echo "❌ HTTPRoute parent gateway is '${PARENT_GATEWAY}', expected '${GATEWAY_NAME}'"
  ((ERRORS++))
else
  echo "✅ HTTPRoute references Gateway: ${GATEWAY_NAME}"
fi

# Verify Hostname
ROUTE_HOSTNAME=$(echo "${ROUTE_JSON}" | jq -r '.spec.hostnames[0] // empty')
if [[ "${ROUTE_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ HTTPRoute hostname is '${ROUTE_HOSTNAME}', expected '${HOSTNAME}'"
  ((ERRORS++))
else
  echo "✅ HTTPRoute hostname: ${HOSTNAME}"
fi

# Verify Routes
echo ""
echo "🛣️  Checking routing rules..."

RULES_COUNT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules | length')
if [[ "${RULES_COUNT}" -lt 2 ]]; then
  echo "❌ Found ${RULES_COUNT} routing rules, expected at least 2 (/games and /players)"
  ((ERRORS++))
else
  echo "✅ Found ${RULES_COUNT} routing rules"
fi

# Check /games route
GAMES_PATH=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/games") | .matches[0].path.value' 2>/dev/null || echo "")
GAMES_SVC=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/games") | .backendRefs[0].name' 2>/dev/null || echo "")
GAMES_PORT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/games") | .backendRefs[0].port' 2>/dev/null || echo "")

if [[ "${GAMES_PATH}" != "/games" ]]; then
  echo "❌ Route for /games not found"
  ((ERRORS++))
elif [[ "${GAMES_SVC}" != "${SVC_GAMES}" ]]; then
  echo "❌ /games route points to '${GAMES_SVC}', expected '${SVC_GAMES}'"
  ((ERRORS++))
elif [[ "${GAMES_PORT}" != "80" ]]; then
  echo "❌ /games route uses port '${GAMES_PORT}', expected '80'"
  ((ERRORS++))
else
  echo "✅ Route /games → ${SVC_GAMES}:${GAMES_PORT}"
fi

# Check /players route
PLAYERS_PATH=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/players") | .matches[0].path.value' 2>/dev/null || echo "")
PLAYERS_SVC=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/players") | .backendRefs[0].name' 2>/dev/null || echo "")
PLAYERS_PORT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[] | select(.matches[0].path.value == "/players") | .backendRefs[0].port' 2>/dev/null || echo "")

if [[ "${PLAYERS_PATH}" != "/players" ]]; then
  echo "❌ Route for /players not found"
  ((ERRORS++))
elif [[ "${PLAYERS_SVC}" != "${SVC_PLAYERS}" ]]; then
  echo "❌ /players route points to '${PLAYERS_SVC}', expected '${SVC_PLAYERS}'"
  ((ERRORS++))
elif [[ "${PLAYERS_PORT}" != "80" ]]; then
  echo "❌ /players route uses port '${PLAYERS_PORT}', expected '80'"
  ((ERRORS++))
else
  echo "✅ Route /players → ${SVC_PLAYERS}:${PLAYERS_PORT}"
fi

# Check HTTPRoute Status
echo ""
echo "🔍 Checking HTTPRoute status..."
ROUTE_ACCEPTED=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "Unknown")

if [[ "${ROUTE_ACCEPTED}" == "True" ]]; then
  echo "✅ HTTPRoute is Accepted by Gateway"
else
  echo "⚠️  HTTPRoute Accepted status: ${ROUTE_ACCEPTED}"
  echo "   The HTTPRoute may still be processing..."
fi

# Verify Services exist
echo ""
echo "🔍 Verifying backend services..."

if ! kubectl get svc "${SVC_GAMES}" -n "${NAMESPACE}" &>/dev/null; then
  echo "⚠️  Service '${SVC_GAMES}' not found"
else
  GAMES_ENDPOINTS=$(kubectl get endpoints "${SVC_GAMES}" -n "${NAMESPACE}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
  if [[ -z "${GAMES_ENDPOINTS}" ]] || [[ "${GAMES_ENDPOINTS}" == "null" ]]; then
    echo "⚠️  Service '${SVC_GAMES}' has no ready endpoints"
  else
    echo "✅ Service '${SVC_GAMES}' is ready"
  fi
fi

if ! kubectl get svc "${SVC_PLAYERS}" -n "${NAMESPACE}" &>/dev/null; then
  echo "⚠️  Service '${SVC_PLAYERS}' not found"
else
  PLAYERS_ENDPOINTS=$(kubectl get endpoints "${SVC_PLAYERS}" -n "${NAMESPACE}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
  if [[ -z "${PLAYERS_ENDPOINTS}" ]] || [[ "${PLAYERS_ENDPOINTS}" == "null" ]]; then
    echo "⚠️  Service '${SVC_PLAYERS}' has no ready endpoints"
  else
    echo "✅ Service '${SVC_PLAYERS}' is ready"
  fi
fi

# Check DNS
echo ""
echo "🔍 Checking DNS configuration..."
if grep -q "${HOSTNAME}" /etc/hosts 2>/dev/null; then
  echo "✅ /etc/hosts configured for ${HOSTNAME}"
  HOSTS_IP=$(grep "${HOSTNAME}" /etc/hosts | awk '{print $1}' | head -n1)
  echo "   Configured IP: ${HOSTS_IP}"
else
  echo "ℹ️  ${HOSTNAME} not found in /etc/hosts"
  echo "💡 To test: echo '192.168.1.240 ${HOSTNAME}' | sudo tee -a /etc/hosts"
fi

# Try to test connectivity
if grep -q "${HOSTNAME}" /etc/hosts 2>/dev/null && command -v curl &>/dev/null; then
  echo ""
  echo "🧪 Testing HTTPS connectivity..."
  
  # Test /games
  GAMES_HTTP=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${HOSTNAME}/games" 2>/dev/null || echo "000")
  if [[ "${GAMES_HTTP}" == "200" ]]; then
    echo "✅ /games endpoint accessible (HTTP ${GAMES_HTTP})"
    GAMES_RESPONSE=$(curl -k -s --max-time 5 "https://${HOSTNAME}/games" 2>/dev/null || echo "")
    if echo "${GAMES_RESPONSE}" | jq -e '.service' &>/dev/null; then
      SERVICE_NAME=$(echo "${GAMES_RESPONSE}" | jq -r '.service')
      echo "   Service: ${SERVICE_NAME}"
    fi
  else
    echo "⚠️  /games endpoint returned HTTP ${GAMES_HTTP}"
    ((ERRORS++))
  fi
  
  # Test /players
  PLAYERS_HTTP=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${HOSTNAME}/players" 2>/dev/null || echo "000")
  if [[ "${PLAYERS_HTTP}" == "200" ]]; then
    echo "✅ /players endpoint accessible (HTTP ${PLAYERS_HTTP})"
    PLAYERS_RESPONSE=$(curl -k -s --max-time 5 "https://${HOSTNAME}/players" 2>/dev/null || echo "")
    if echo "${PLAYERS_RESPONSE}" | jq -e '.service' &>/dev/null; then
      SERVICE_NAME=$(echo "${PLAYERS_RESPONSE}" | jq -r '.service')
      echo "   Service: ${SERVICE_NAME}"
    fi
  else
    echo "⚠️  /players endpoint returned HTTP ${PLAYERS_HTTP}"
    ((ERRORS++))
  fi
fi



IP_TO_CHECK="192.168.1.240"
FILE="/etc/hosts"

if grep -q "$IP_TO_CHECK" "$FILE"; then
    echo "ERROR: IP address $IP_TO_CHECK is still present in $FILE"
    exit 1
else
    echo "OK: IP address $IP_TO_CHECK not found."
fi


# Final verdict
echo ""
echo "═══════════════════════════════════════════════════════════"

if [[ ${ERRORS} -eq 0 ]]; then
  echo ""
  echo "🎉 GAME CLEARED! 🎴"
  echo ""
  echo "✅ All clear conditions met!"
  echo ""
  echo "📊 Migration Summary:"
  echo "   • Gateway: ${GATEWAY_NAME} (HTTPS on port 443)"
  echo "   • HTTPRoute: ${HTTPROUTE_NAME}"
  echo "   • TLS: Enabled with ${TLS_SECRET} secret"
  echo "   • Routes:"
  echo "     - /games → ${SVC_GAMES}"
  echo "     - /players → ${SVC_PLAYERS}"
  echo ""
  echo "🃏 You have successfully migrated from Ingress to Gateway API!"
  echo "⏱️  Your visa has been extended. You survive another day!"
  echo ""
  echo "👥 Arisu: 'Impressive work on the migration.'"
  echo "😏 Chishiya: 'Adapting quickly. That's how you survive here.'"
  echo "👩 Usagi: 'You did it! Let's move to the next game.'"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  exit 0
else
  echo ""
  echo "💀 GAME OVER"
  echo ""
  echo "❌ Found ${ERRORS} error(s)"
  echo ""
  echo "⚠️  Your visa has expired. The migration failed."
  echo ""
  echo "💡 Review the errors above and try again."
  echo "💡 Time is running out in the Borderland..."
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi
