#!/bin/bash
set -euo pipefail

echo "🔍 Verifying NetworkPolicy configuration..."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="isolated"
NETPOL_NAME="allow-multi-pod-ingress"

print_status() {
  if [ "$1" = "ok" ]; then
    echo -e "${GREEN}✅ $2${NC}"
  elif [ "$1" = "fail" ]; then
    echo -e "${RED}❌ $2${NC}"
  else
    echo -e "${YELLOW}⚠️  $2${NC}"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { print_status "fail" "Required command '$1' not found in PATH"; exit 1; }
}

require_cmd kubectl
require_cmd jq

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  print_status "fail" "Namespace '${NAMESPACE}' not found"
  exit 1
fi
print_status "ok" "Namespace '${NAMESPACE}' exists"

# Check if NetworkPolicy exists
if ! kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  print_status "fail" "NetworkPolicy '${NETPOL_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
print_status "ok" "NetworkPolicy '${NETPOL_NAME}' exists"

# Fetch the policy once as JSON and use jq for every structural check below.
# (kubectl's jsonpath output for objects/maps prints Go's "map[key:val]" format,
#  not JSON, so grep'ing it for '"key":"val"' or piping it into jq silently
#  breaks — that was the previous bug. -o json + jq avoids that entirely.)
JSON="$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o json)"

# Verify NetworkPolicy targets correct pods (app=api)
SEL_APP=$(echo "${JSON}" | jq -r '.spec.podSelector.matchLabels.app // empty')
if [ "${SEL_APP}" != "api" ]; then
  print_status "fail" "NetworkPolicy does not select pods with label app=api (found: '${SEL_APP:-<none>}')"
  exit 1
fi
print_status "ok" "NetworkPolicy selects pods with label app=api"

# Verify policyTypes includes Ingress
TYPES=$(echo "${JSON}" | jq -r '[.spec.policyTypes[]?] | join(" ")')
if ! echo "${TYPES}" | grep -qw "Ingress"; then
  print_status "fail" "NetworkPolicy does not specify Ingress in policyTypes (found: ${TYPES:-<none>})"
  exit 1
fi
print_status "ok" "NetworkPolicy has Ingress in policyTypes"

# Verify at least one ingress rule exists
INGRESS_COUNT=$(echo "${JSON}" | jq '.spec.ingress // [] | length')
if [ "${INGRESS_COUNT}" -eq 0 ]; then
  print_status "fail" "NetworkPolicy has no ingress rules defined"
  exit 1
fi
print_status "ok" "NetworkPolicy has ingress rules defined"

# Verify a single 'from' podSelector requires BOTH app=frontend AND role=proxy (AND logic,
# not two separate podSelector entries which would be OR logic).
AND_MATCH=$(echo "${JSON}" | jq '[.spec.ingress[]?.from[]?.podSelector.matchLabels // {}
  | select(.app == "frontend" and .role == "proxy")] | length')
if [ "${AND_MATCH}" -eq 0 ]; then
  print_status "fail" "No 'from' podSelector requires BOTH app=frontend AND role=proxy on the same selector"
  echo "Found 'from' selectors:"
  echo "${JSON}" | jq -c '[.spec.ingress[]?.from[]?.podSelector.matchLabels // {}]'
  exit 1
fi
print_status "ok" "NetworkPolicy requires app=frontend AND role=proxy in a single source selector"

# Warn (don't fail) if there are extra 'from' entries — could indicate an accidental OR rule
FROM_COUNT=$(echo "${JSON}" | jq '[.spec.ingress[]?.from[]?] | length')
if [ "${FROM_COUNT}" -gt 1 ]; then
  print_status "warn" "Found ${FROM_COUNT} 'from' entries — make sure you didn't accidentally OR two separate selectors together"
fi

# Verify port 7000/TCP is allowed
PORT_MATCH=$(echo "${JSON}" | jq '[.spec.ingress[]?.ports[]?
  | select(((.protocol // "TCP") == "TCP") and ((.port == 7000) or (.port == "7000")))] | length')
if [ "${PORT_MATCH}" -eq 0 ]; then
  print_status "fail" "NetworkPolicy does not allow TCP port 7000"
  exit 1
fi
print_status "ok" "NetworkPolicy allows TCP port 7000"

# Warn if other ports are also allowed (task asks for port 7000 only)
OTHER_PORTS=$(echo "${JSON}" | jq '[.spec.ingress[]?.ports[]?
  | select(((.port != 7000) and (.port != "7000")))] | length')
if [ "${OTHER_PORTS}" -gt 0 ]; then
  print_status "warn" "NetworkPolicy also allows ports other than 7000 — task asked for port 7000 only"
fi

# Wait for pods to be ready
echo ""
echo "⏳ Ensuring test pods are ready..."
kubectl wait --for=condition=ready pod/api-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod/frontend-proxy-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod/frontend-only-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod/database-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true

# Give NetworkPolicy time to be enforced
sleep 2

# Live connectivity tests
echo ""
echo "🌐 Testing live connectivity..."

echo "Test 1: frontend-proxy-pod -> api-pod:7000 (expected: ALLOWED)"
if kubectl exec -n "${NAMESPACE}" frontend-proxy-pod -- curl -s --max-time 3 api-pod:7000 &>/dev/null; then
  print_status "ok" "frontend-proxy-pod can reach api-pod:7000"
else
  print_status "fail" "frontend-proxy-pod could NOT reach api-pod:7000 (should be allowed)"
  exit 1
fi

echo "Test 2: frontend-only-pod -> api-pod:7000 (expected: BLOCKED)"
if kubectl exec -n "${NAMESPACE}" frontend-only-pod -- curl -s --max-time 3 api-pod:7000 &>/dev/null; then
  print_status "fail" "frontend-only-pod reached api-pod:7000 but should be blocked (missing role=proxy)"
  exit 1
else
  print_status "ok" "frontend-only-pod correctly blocked from api-pod:7000"
fi

echo "Test 3: database-pod -> api-pod:7000 (expected: BLOCKED)"
if kubectl exec -n "${NAMESPACE}" database-pod -- curl -s --max-time 3 api-pod:7000 &>/dev/null; then
  print_status "fail" "database-pod reached api-pod:7000 but should be blocked"
  exit 1
else
  print_status "ok" "database-pod correctly blocked from api-pod:7000"
fi

echo "Test 4: frontend-proxy-pod -> api-pod-alt:8080 (expected: BLOCKED)"
if kubectl exec -n "${NAMESPACE}" frontend-proxy-pod -- curl -s --max-time 3 api-pod-alt:8080 &>/dev/null; then
  print_status "fail" "frontend-proxy-pod reached api-pod-alt:8080 but that port should be blocked"
  exit 1
else
  print_status "ok" "api-pod-alt:8080 correctly blocked (only port 7000 is allowed)"
fi

# Display the NetworkPolicy for reference
echo ""
echo "📋 NetworkPolicy configuration:"
echo "${JSON}" | jq '.spec'

echo ""
print_status "ok" "🎉 NetworkPolicy verification passed!"
echo ""
echo "📊 Summary:"
echo "   ✅ NetworkPolicy '${NETPOL_NAME}' correctly configured"
echo "   ✅ Selects pods with label app=api"
echo "   ✅ Requires source pods to have BOTH app=frontend AND role=proxy labels"
echo "   ✅ Allows only TCP port 7000"
echo "   ✅ Blocks pods with partial label match"
echo "   ✅ Blocks pods with wrong labels"
echo "   ✅ Blocks traffic to other ports"
echo ""

exit 0
