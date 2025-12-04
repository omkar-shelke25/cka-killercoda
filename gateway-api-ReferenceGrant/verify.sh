#!/bin/bash
set -euo pipefail

GATEWAY_NS="gateway-system"
UI_NS="pokedex-ui"
CORE_NS="pokedex-core"
GATEWAY_NAME="kanto-gateway"
HTTPROUTE_NAME="trainer-api-route"
SERVICE_NAME="evolution-engine"
SERVICE_PORT="9000"

echo "🔍 Verifying CKA Task: ReferenceGrant Configuration..."
echo ""

# Check if manifest file exists
if [[ ! -f "/root/poke-refgrant.yaml" ]]; then
  echo "❌ File not found: /root/poke-refgrant.yaml"
  echo "💡 Hint: Save your ReferenceGrant manifest to /root/poke-refgrant.yaml"
  exit 1
fi
echo "✅ Manifest file exists: /root/poke-refgrant.yaml"

# Check if ReferenceGrant exists in correct namespace
REFGRANT_COUNT=$(kubectl get referencegrant -n "${CORE_NS}" --no-headers 2>/dev/null | wc -l)
if [[ "${REFGRANT_COUNT}" -eq 0 ]]; then
  echo "❌ No ReferenceGrant found in namespace '${CORE_NS}'"
  echo "💡 Hint: Apply your manifest with: kubectl apply -f /root/poke-refgrant.yaml"
  echo "💡 Hint: ReferenceGrant must be in the TARGET namespace (where the Service lives)"
  exit 1
fi
echo "✅ ReferenceGrant exists in namespace '${CORE_NS}'"

# Get the first ReferenceGrant name
REFGRANT_NAME=$(kubectl get referencegrant -n "${CORE_NS}" -o jsonpath='{.items[0].metadata.name}')
echo "   ReferenceGrant name: ${REFGRANT_NAME}"

# Verify API version
API_VERSION=$(kubectl get referencegrant "${REFGRANT_NAME}" -n "${CORE_NS}" -o jsonpath='{.apiVersion}')
if [[ "${API_VERSION}" != "gateway.networking.k8s.io/v1beta1" ]] && [[ "${API_VERSION}" != "gateway.networking.k8s.io/v1alpha2" ]]; then
  echo "❌ ReferenceGrant apiVersion is '${API_VERSION}', expected 'gateway.networking.k8s.io/v1beta1'"
  exit 1
fi
echo "✅ ReferenceGrant apiVersion: ${API_VERSION}"

# Get ReferenceGrant JSON for detailed verification
REFGRANT_JSON=$(kubectl get referencegrant "${REFGRANT_NAME}" -n "${CORE_NS}" -o json)

# Verify 'from' section
echo ""
echo "🔍 Verifying 'from' configuration (source)..."

FROM_COUNT=$(echo "${REFGRANT_JSON}" | jq -r '.spec.from | length' 2>/dev/null || echo "0")
if [[ "${FROM_COUNT}" -eq 0 ]]; then
  echo "❌ No 'from' entries found in ReferenceGrant"
  echo "💡 Hint: Add spec.from section to specify allowed source"
  exit 1
fi

# Check first 'from' entry
FROM_GROUP=$(echo "${REFGRANT_JSON}" | jq -r '.spec.from[0].group' 2>/dev/null || echo "")
FROM_KIND=$(echo "${REFGRANT_JSON}" | jq -r '.spec.from[0].kind' 2>/dev/null || echo "")
FROM_NS=$(echo "${REFGRANT_JSON}" | jq -r '.spec.from[0].namespace' 2>/dev/null || echo "")

if [[ "${FROM_GROUP}" != "gateway.networking.k8s.io" ]]; then
  echo "❌ From group is '${FROM_GROUP}', expected 'gateway.networking.k8s.io'"
  echo "💡 Hint: HTTPRoute belongs to gateway.networking.k8s.io group"
  exit 1
fi
echo "✅ From group: gateway.networking.k8s.io"

if [[ "${FROM_KIND}" != "HTTPRoute" ]]; then
  echo "❌ From kind is '${FROM_KIND}', expected 'HTTPRoute'"
  echo "💡 Hint: The source resource is an HTTPRoute"
  exit 1
fi
echo "✅ From kind: HTTPRoute"

if [[ "${FROM_NS}" != "${UI_NS}" ]]; then
  echo "❌ From namespace is '${FROM_NS}', expected '${UI_NS}'"
  echo "💡 Hint: The HTTPRoute is in namespace '${UI_NS}'"
  exit 1
fi
echo "✅ From namespace: ${UI_NS}"

# Verify 'to' section
echo ""
echo "🔍 Verifying 'to' configuration (target)..."

TO_COUNT=$(echo "${REFGRANT_JSON}" | jq -r '.spec.to | length' 2>/dev/null || echo "0")
if [[ "${TO_COUNT}" -eq 0 ]]; then
  echo "❌ No 'to' entries found in ReferenceGrant"
  echo "💡 Hint: Add spec.to section to specify allowed target"
  exit 1
fi

# Check first 'to' entry
TO_GROUP=$(echo "${REFGRANT_JSON}" | jq -r '.spec.to[0].group' 2>/dev/null || echo "null")
TO_KIND=$(echo "${REFGRANT_JSON}" | jq -r '.spec.to[0].kind' 2>/dev/null || echo "")
TO_NAME=$(echo "${REFGRANT_JSON}" | jq -r '.spec.to[0].name' 2>/dev/null || echo "null")

# Check group (should be empty string for core API)
if [[ "${TO_GROUP}" != '""' ]] && [[ "${TO_GROUP}" != "" ]] && [[ "${TO_GROUP}" != "null" ]]; then
  # Additional check - extract raw value
  TO_GROUP_RAW=$(echo "${REFGRANT_JSON}" | jq -r '.spec.to[0] | has("group")' 2>/dev/null)
  if [[ "${TO_GROUP_RAW}" == "true" ]]; then
    TO_GROUP_VALUE=$(echo "${REFGRANT_JSON}" | jq -r '.spec.to[0].group' 2>/dev/null)
    if [[ "${TO_GROUP_VALUE}" != "" ]]; then
      echo "❌ To group is '${TO_GROUP_VALUE}', expected empty string (\"\") for core API"
      echo "💡 Hint: Services are in core API group, use: group: \"\""
      exit 1
    fi
  fi
fi
echo "✅ To group: \"\" (core API)"

if [[ "${TO_KIND}" != "Service" ]]; then
  echo "❌ To kind is '${TO_KIND}', expected 'Service'"
  echo "💡 Hint: The target resource is a Service"
  exit 1
fi
echo "✅ To kind: Service"

# Check if service name is specified (security best practice)
if [[ "${TO_NAME}" == "null" ]] || [[ -z "${TO_NAME}" ]]; then
  echo "⚠️  Warning: No specific service name specified"
  echo "💡 Best practice: Specify name: ${SERVICE_NAME} to restrict access to specific service"
  echo "   (Accepting this, but in production you should specify the service name)"
elif [[ "${TO_NAME}" != "${SERVICE_NAME}" ]]; then
  echo "❌ To name is '${TO_NAME}', expected '${SERVICE_NAME}'"
  echo "💡 Hint: Grant access specifically to service '${SERVICE_NAME}'"
  exit 1
else
  echo "✅ To name: ${SERVICE_NAME} (specific service - secure!)"
fi

# Check HTTPRoute status
echo ""
echo "🔍 Checking HTTPRoute status..."

# Wait a moment for reconciliation
sleep 2

if ! kubectl get httproute "${HTTPROUTE_NAME}" -n "${UI_NS}" &>/dev/null; then
  echo "⚠️  HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${UI_NS}'"
  echo "   This should exist from setup. Continuing verification..."
else
  # Check if HTTPRoute is accepted
  ROUTE_ACCEPTED=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${UI_NS}" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null || echo "Unknown")
  
  if [[ "${ROUTE_ACCEPTED}" == "True" ]]; then
    echo "✅ HTTPRoute is Accepted by Gateway"
    
    # Check if backend refs are resolved
    ROUTE_RESOLVED=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${UI_NS}" -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null || echo "Unknown")
    if [[ "${ROUTE_RESOLVED}" == "True" ]]; then
      echo "✅ HTTPRoute backend references resolved successfully"
    else
      echo "⚠️  HTTPRoute backend refs status: ${ROUTE_RESOLVED}"
      echo "   This may take a moment to reconcile..."
    fi
  else
    echo "⚠️  HTTPRoute Accepted status: ${ROUTE_ACCEPTED}"
    echo "   Checking for errors..."
    kubectl describe httproute "${HTTPROUTE_NAME}" -n "${UI_NS}" | grep -A 5 "Conditions:" || true
  fi
fi

# Verify Service exists
echo ""
echo "🔍 Verifying backend service..."

if ! kubectl get svc "${SERVICE_NAME}" -n "${CORE_NS}" &>/dev/null; then
  echo "⚠️  Service '${SERVICE_NAME}' not found in namespace '${CORE_NS}'"
else
  SVC_PORT=$(kubectl get svc "${SERVICE_NAME}" -n "${CORE_NS}" -o jsonpath='{.spec.ports[0].port}')
  if [[ "${SVC_PORT}" == "${SERVICE_PORT}" ]]; then
    echo "✅ Service '${SERVICE_NAME}' exists on port ${SERVICE_PORT}"
  else
    echo "⚠️  Service port is ${SVC_PORT}, expected ${SERVICE_PORT}"
  fi
  
  # Check endpoints
  ENDPOINTS=$(kubectl get endpoints "${SERVICE_NAME}" -n "${CORE_NS}" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
  if [[ -z "${ENDPOINTS}" ]] || [[ "${ENDPOINTS}" == "null" ]]; then
    echo "⚠️  Service has no ready endpoints"
  else
    echo "✅ Service has ready endpoints"
  fi
fi

# Check Gateway
echo ""
echo "🔍 Checking Gateway..."

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

# Check DNS configuration
echo ""
echo "🔍 Checking DNS configuration..."
HOSTNAME="pokedex.kanto.lab"

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
  echo "🧪 Testing API connectivity..."
  
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${HOSTNAME}/api/evolution" 2>/dev/null || echo "000")
  
  if [[ "${HTTP_CODE}" == "200" ]]; then
    echo "✅ API endpoint is accessible (HTTP ${HTTP_CODE})"
    
    # Test response content
    RESPONSE=$(curl -s --max-time 5 "http://${HOSTNAME}/api/evolution" 2>/dev/null || echo "")
    if echo "${RESPONSE}" | jq -e '.service' &>/dev/null; then
      SERVICE_TITLE=$(echo "${RESPONSE}" | jq -r '.service')
      echo "✅ Received valid response from: ${SERVICE_TITLE}"
      
      # Check if it's the evolution engine
      if [[ "${SERVICE_TITLE}" == "Evolution Engine" ]]; then
        echo "✅ Confirmed: Evolution Engine is accessible!"
        PROFESSOR=$(echo "${RESPONSE}" | jq -r '.professor' 2>/dev/null || echo "")
        if [[ -n "${PROFESSOR}" ]]; then
          echo "   👨‍🔬 ${PROFESSOR} approves!"
        fi
      fi
    fi
  else
    echo "⚠️  Could not access API endpoint (HTTP ${HTTP_CODE})"
    if [[ "${HTTP_CODE}" == "000" ]]; then
      echo "   Gateway may still be initializing..."
    fi
  fi
fi

# Final summary
echo ""
echo "🎉 ReferenceGrant verification complete!"
echo ""
echo "📊 Configuration Summary:"
echo "   • ReferenceGrant: ${REFGRANT_NAME} (${CORE_NS})"
echo "   • From: HTTPRoute in namespace ${UI_NS}"
echo "   • To: Service '${SERVICE_NAME}' in namespace ${CORE_NS}"
echo "   • Gateway: ${GATEWAY_NAME} (${GATEWAY_NS})"
echo "   • HTTPRoute: ${HTTPROUTE_NAME} (${UI_NS})"
echo ""
echo "✅ CKA Task completed successfully!"
echo "🎮 Cross-namespace access has been granted!"
echo "⚡ Trainers can now access Pokémon evolution data!"
echo "👨‍🔬 Professor Oak is pleased with your work!"
echo ""
exit 0
