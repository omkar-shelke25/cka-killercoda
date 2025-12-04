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
PATH_EXPECT="/recommendations"
WEIGHT_V1="90"
WEIGHT_V2="10"

echo "🔍 Verifying CKA Task: Gateway API Canary Deployment..."
echo ""

if [[ ! -f "/root/st-canary.yaml" ]]; then
  echo "❌ File not found: /root/st-canary.yaml"
  exit 1
fi
echo "✅ Manifest exists: /root/st-canary.yaml"

if ! kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" &>/dev/null; then
  echo "❌ HTTPRoute '${HTTPROUTE_NAME}' not found in namespace '${APP_NS}'"
  echo "   Run: kubectl apply -f /root/st-canary.yaml"
  exit 1
fi
echo "✅ HTTPRoute exists: ${HTTPROUTE_NAME} (ns: ${APP_NS})"

ROUTE_JSON=$(kubectl get httproute "${HTTPROUTE_NAME}" -n "${APP_NS}" -o json)

echo ""
echo "🧾 Raw HTTPRoute (trimmed):"
echo "${ROUTE_JSON}" | jq '.spec | {parentRefs: .parentRefs, hostnames: .hostnames, rules: .rules}' || true
echo ""

# ParentRefs check (more verbose)
PARENT_GATEWAY=$(echo "${ROUTE_JSON}" | jq -r '.spec.parentRefs[0].name // empty')
PARENT_NS=$(echo "${ROUTE_JSON}" | jq -r '.spec.parentRefs[0].namespace // empty')

echo "🔎 parentRefs.name: '${PARENT_GATEWAY}', parentRefs.namespace: '${PARENT_NS:-<empty>}'"

if [[ "${PARENT_GATEWAY}" != "${GATEWAY_NAME}" ]]; then
  echo "❌ parentRefs.name mismatch: found '${PARENT_GATEWAY}', expected '${GATEWAY_NAME}'"
  echo "   Suggestion: ensure parentRefs[0].name: ${GATEWAY_NAME}"
  echo "   (kubectl get -n ${APP_NS} httproute/${HTTPROUTE_NAME} -o yaml | sed -n '1,120p')"
  exit 1
fi
echo "✅ parentRefs.name ok"

# If parent namespace is empty -> document behaviour and fail if expected different NS
if [[ -z "${PARENT_NS}" ]]; then
  echo "⚠ parentRefs.namespace is empty — when omitted the parent Gateway is assumed to be in the same namespace as the HTTPRoute (${APP_NS})."
  echo "   Your expected gateway namespace is '${GATEWAY_NS}'. If your Gateway is in '${GATEWAY_NS}', add parentRefs[0].namespace: ${GATEWAY_NS} to the HTTPRoute."
  if [[ "${GATEWAY_NS}" != "${APP_NS}" ]]; then
    echo "❌ parentRefs.namespace missing and does not match expected ${GATEWAY_NS}"
    exit 1
  else
    echo "✅ OK: gateway and httproute in same namespace (${APP_NS})"
  fi
else
  if [[ "${PARENT_NS}" != "${GATEWAY_NS}" ]]; then
    echo "❌ parentRefs.namespace mismatch: found '${PARENT_NS}', expected '${GATEWAY_NS}'"
    exit 1
  fi
  echo "✅ parentRefs.namespace ok: ${PARENT_NS}"
fi

# Hostname check
ROUTE_HOSTNAME=$(echo "${ROUTE_JSON}" | jq -r '.spec.hostnames[0] // empty')
if [[ "${ROUTE_HOSTNAME}" != "${HOSTNAME}" ]]; then
  echo "❌ hostname mismatch: found '${ROUTE_HOSTNAME}', expected '${HOSTNAME}'"
  echo "   Hint: .spec.hostnames should include '${HOSTNAME}'"
  exit 1
fi
echo "✅ hostname ok: ${HOSTNAME}"

# Path matching: normalize trailing slash differences
PATH_TYPE=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].matches[0].path.type // empty')
PATH_VALUE_RAW=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].matches[0].path.value // empty')
# normalize by trimming trailing slash for comparison
norm() { echo "$1" | sed 's:/*$::'; }
if [[ -z "${PATH_TYPE}" ]]; then
  echo "❌ path.match missing in HTTPRoute rule"
  exit 1
fi
if [[ "${PATH_TYPE}" != "PathPrefix" ]]; then
  echo "❌ path.type is '${PATH_TYPE}', expected 'PathPrefix'"
  exit 1
fi
if [[ "$(norm "${PATH_VALUE_RAW}")" != "$(norm "${PATH_EXPECT}")" ]]; then
  echo "❌ path.value mismatch: found '${PATH_VALUE_RAW}', expected '${PATH_EXPECT}'"
  exit 1
fi
echo "✅ path ok: type=${PATH_TYPE} value='${PATH_VALUE_RAW}'"

# BackendRefs & weights
BACKENDS_COUNT=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs | length // 0')
if [[ "${BACKENDS_COUNT}" -ne 2 ]]; then
  echo "❌ expected 2 backendRefs but found ${BACKENDS_COUNT}"
  echo "   Hint: include two backendRefs (stv-v1 and stv-v2) with weights"
  exit 1
fi
echo "✅ 2 backendRefs found"

# Extract both backends robustly
BE0=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[0]')
BE1=$(echo "${ROUTE_JSON}" | jq -r '.spec.rules[0].backendRefs[1]')

# Helper to extract fields
get_field() {
  echo "$1" | jq -r ".${2} // empty"
}

B0_NAME=$(get_field "${BE0}" "name")
B0_PORT=$(get_field "${BE0}" "port")
B0_WEIGHT=$(get_field "${BE0}" "weight")

B1_NAME=$(get_field "${BE1}" "name")
B1_PORT=$(get_field "${BE1}" "port")
B1_WEIGHT=$(get_field "${BE1}" "weight")

echo "🔎 backendRefs[0]: name='${B0_NAME}', port='${B0_PORT}', weight='${B0_WEIGHT}'"
echo "🔎 backendRefs[1]: name='${B1_NAME}', port='${B1_PORT}', weight='${B1_WEIGHT}'"

# map to v1/v2
if [[ "${B0_NAME}" == "${SVC_V1}" ]]; then
  V1_WEIGHT="${B0_WEIGHT}"
  V1_PORT="${B0_PORT}"
  V2_WEIGHT="${B1_WEIGHT}"
  V2_PORT="${B1_PORT}"
elif [[ "${B0_NAME}" == "${SVC_V2}" ]]; then
  V2_WEIGHT="${B0_WEIGHT}"
  V2_PORT="${B0_PORT}"
  V1_WEIGHT="${B1_WEIGHT}"
  V1_PORT="${B1_PORT}"
else
  echo "❌ Unexpected backend name: ${B0_NAME}"
  exit 1
fi

# port checks: allow numeric or string; if empty -> warn
if [[ -z "${V1_PORT}" ]]; then
  echo "⚠️  stv-v1 port is not explicitly set in backendRefs — check service port mapping"
else
  if [[ "${V1_PORT}" != "${PORT}" ]]; then
    echo "❌ stv-v1 port mismatch: found '${V1_PORT}', expected '${PORT}'"
    exit 1
  fi
  echo "✅ stv-v1 port ${V1_PORT}"
fi

if [[ -z "${V2_PORT}" ]]; then
  echo "⚠️  stv-v2 port is not explicitly set in backendRefs — check service port mapping"
else
  if [[ "${V2_PORT}" != "${PORT}" ]]; then
    echo "❌ stv-v2 port mismatch: found '${V2_PORT}', expected '${PORT}'"
    exit 1
  fi
  echo "✅ stv-v2 port ${V2_PORT}"
fi

# weight checks: ensure numeric and present
if ! [[ "${V1_WEIGHT}" =~ ^[0-9]+$ ]]; then
  echo "❌ stv-v1 weight not numeric or missing: '${V1_WEIGHT}'"
  exit 1
fi
if ! [[ "${V2_WEIGHT}" =~ ^[0-9]+$ ]]; then
  echo "❌ stv-v2 weight not numeric or missing: '${V2_WEIGHT}'"
  exit 1
fi
if [[ "${V1_WEIGHT}" -ne "${WEIGHT_V1}" ]]; then
  echo "❌ stv-v1 weight mismatch: found ${V1_WEIGHT}, expected ${WEIGHT_V1}"
  exit 1
fi
if [[ "${V2_WEIGHT}" -ne "${WEIGHT_V2}" ]]; then
  echo "❌ stv-v2 weight mismatch: found ${V2_WEIGHT}, expected ${WEIGHT_V2}"
  exit 1
fi
echo "✅ weights ok: ${SVC_V1}=${V1_WEIGHT}, ${SVC_V2}=${V2_WEIGHT}"

TOTAL=$((V1_WEIGHT + V2_WEIGHT))
V1_PCT=$((V1_WEIGHT * 100 / TOTAL))
V2_PCT=$((V2_WEIGHT * 100 / TOTAL))

echo ""
echo "📊 Traffic split configured: ${SVC_V1}=${V1_PCT}%, ${SVC_V2}=${V2_PCT}%"

# Status check
ROUTE_STATUS=$(echo "${ROUTE_JSON}" | jq -r '.status.parents[0].conditions[]? | select(.type=="Accepted") .status // "Unknown"' 2>/dev/null || echo "Unknown")
if [[ "${ROUTE_STATUS}" == "True" ]]; then
  echo "✅ HTTPRoute Accepted by Gateway"
else
  echo "⚠️  HTTPRoute status: ${ROUTE_STATUS}"
  echo "   Run: kubectl describe httproute ${HTTPROUTE_NAME} -n ${APP_NS}"
fi

# Services & endpoints
for svc in "${SVC_V1}" "${SVC_V2}"; do
  if ! kubectl get svc "${svc}" -n "${APP_NS}" &>/dev/null; then
    echo "❌ Service ${svc} not found in ${APP_NS}"
    exit 1
  fi
  EP=$(kubectl get endpoints "${svc}" -n "${APP_NS}" -o json | jq -r '.subsets[0].addresses // empty')
  if [[ -z "${EP}" ]]; then
    echo "⚠️  Service ${svc} has no ready endpoints"
  else
    echo "✅ Service ${svc} has ready endpoints"
  fi
done

echo ""
echo "🎉 Verification finished. If you still see failures, paste the HTTPRoute YAML (kubectl get httproute -n ${APP_NS} ${HTTPROUTE_NAME} -o yaml) and I will inspect it."
exit 0
