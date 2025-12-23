#!/bin/bash
set -euo pipefail

echo "🔍 Verifying NetworkPolicy deployment..."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  if [ "$1" = "ok" ]; then
    echo -e "${GREEN}✅ $2${NC}"
  elif [ "$1" = "fail" ]; then
    echo -e "${RED}❌ $2${NC}"
  else
    echo -e "${YELLOW}⚠️  $2${NC}"
  fi
}

# Check if NetworkPolicy exists in backend namespace
if ! kubectl get networkpolicy -n backend &>/dev/null; then
  print_status "fail" "No NetworkPolicy found in backend namespace"
  echo "Please deploy one of the NetworkPolicy files from /root/network-policies"
  exit 1
fi

NETPOL_COUNT=$(kubectl get networkpolicy -n backend --no-headers 2>/dev/null | wc -l)
if [[ "${NETPOL_COUNT}" -eq 0 ]]; then
  print_status "fail" "No NetworkPolicy found in backend namespace"
  exit 1
fi

print_status "ok" "NetworkPolicy exists in backend namespace"

# Get the NetworkPolicy name
NETPOL_NAME=$(kubectl get networkpolicy -n backend -o jsonpath='{.items[0].metadata.name}')
echo "Found NetworkPolicy: ${NETPOL_NAME}"

# Check if NetworkPolicy targets backend pods
POD_SELECTOR=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.podSelector.matchLabels}')
if ! echo "${POD_SELECTOR}" | grep -q '"app":"backend"'; then
  print_status "fail" "NetworkPolicy does not target backend pods (app=backend)"
  echo "Found podSelector: ${POD_SELECTOR}"
  exit 1
fi
print_status "ok" "NetworkPolicy targets backend pods correctly"

# Check if policyTypes includes Ingress
POLICY_TYPES=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.policyTypes[*]}')
if ! echo "${POLICY_TYPES}" | grep -q "Ingress"; then
  print_status "fail" "NetworkPolicy does not specify Ingress in policyTypes"
  exit 1
fi
print_status "ok" "NetworkPolicy has Ingress policy type"

# Check if ingress rules exist
INGRESS_RULES=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress}')
if [[ -z "${INGRESS_RULES}" || "${INGRESS_RULES}" == "null" ]]; then
  print_status "fail" "NetworkPolicy has no ingress rules"
  exit 1
fi
print_status "ok" "NetworkPolicy has ingress rules defined"

# CRITICAL: Check if BOTH namespaceSelector AND podSelector are present in the same from item
NAMESPACE_SELECTOR=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector}')
POD_SELECTOR_IN_FROM=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].podSelector}')

if [[ -z "${NAMESPACE_SELECTOR}" || "${NAMESPACE_SELECTOR}" == "null" ]]; then
  print_status "fail" "NetworkPolicy does not use namespaceSelector"
  echo "For cross-namespace communication, namespaceSelector is required"
  exit 1
fi
print_status "ok" "NetworkPolicy uses namespaceSelector"

if [[ -z "${POD_SELECTOR_IN_FROM}" || "${POD_SELECTOR_IN_FROM}" == "null" ]]; then
  print_status "fail" "NetworkPolicy does not use podSelector in the from clause"
  echo "For least permissive access, BOTH namespaceSelector AND podSelector are required"
  exit 1
fi
print_status "ok" "NetworkPolicy uses podSelector in from clause"

# Verify both are in the SAME from item (AND logic)
FULL_FROM=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o json | jq '.spec.ingress[0].from[0]')
if ! echo "${FULL_FROM}" | grep -q "namespaceSelector" || ! echo "${FULL_FROM}" | grep -q "podSelector"; then
  print_status "fail" "namespaceSelector and podSelector must be in the SAME from item (AND logic)"
  echo "Current from clause: ${FULL_FROM}"
  exit 1
fi
print_status "ok" "namespaceSelector and podSelector are combined (AND logic)"

# Check if namespaceSelector targets frontend namespace
NAMESPACE_LABEL=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels}')
if ! echo "${NAMESPACE_LABEL}" | grep -q '"name":"frontend"'; then
  print_status "fail" "NetworkPolicy does not select frontend namespace"
  echo "Found namespaceSelector labels: ${NAMESPACE_LABEL}"
  exit 1
fi
print_status "ok" "NetworkPolicy selects frontend namespace"

# Check if podSelector targets app=frontend
POD_LABEL=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels}')
if ! echo "${POD_LABEL}" | grep -q '"app":"frontend"'; then
  print_status "fail" "NetworkPolicy does not select app=frontend pods"
  echo "Found podSelector labels: ${POD_LABEL}"
  exit 1
fi
print_status "ok" "NetworkPolicy selects app=frontend pods"

# Check if port 8080 is allowed
PORT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].ports[0].port}')
if [[ "${PORT}" != "8080" ]]; then
  print_status "fail" "NetworkPolicy does not allow port 8080 (found: ${PORT})"
  exit 1
fi
print_status "ok" "NetworkPolicy allows port 8080"

# Check protocol is TCP
PROTOCOL=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].ports[0].protocol}')
if [[ "${PROTOCOL}" != "TCP" ]]; then
  print_status "fail" "NetworkPolicy protocol is not TCP (found: ${PROTOCOL})"
  exit 1
fi
print_status "ok" "NetworkPolicy uses TCP protocol"

# Check that ONLY one port is allowed (least permissive)
PORT_COUNT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o json | jq '.spec.ingress[0].ports | length')
if [[ "${PORT_COUNT}" -gt 1 ]]; then
  print_status "fail" "NetworkPolicy allows ${PORT_COUNT} ports (should be only 1 - port 8080)"
  echo "The policy should be least permissive and allow only port 8080"
  exit 1
fi
print_status "ok" "NetworkPolicy allows only one port (least permissive)"

# Check that there's no ipBlock (security issue for this scenario)
IP_BLOCK=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o json | jq '.spec.ingress[0].from[1].ipBlock // empty')
if [[ -n "${IP_BLOCK}" ]]; then
  print_status "fail" "NetworkPolicy contains ipBlock which is not required and too permissive"
  echo "For least permissive access, do not include ipBlock"
  exit 1
fi
print_status "ok" "NetworkPolicy does not contain unnecessary ipBlock"

# Check that podSelector is not empty (would be security issue)
if echo "${POD_SELECTOR_IN_FROM}" | grep -q "^{}$"; then
  print_status "fail" "NetworkPolicy uses empty podSelector (too permissive)"
  echo "Empty podSelector {} allows all pods, which is not least permissive"
  exit 1
fi
print_status "ok" "NetworkPolicy does not use empty podSelector"

# Check that from clause exists and is not empty
FROM_CLAUSE=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from}')
if [[ -z "${FROM_CLAUSE}" || "${FROM_CLAUSE}" == "null" || "${FROM_CLAUSE}" == "[]" ]]; then
  print_status "fail" "NetworkPolicy is missing 'from' clause (allows traffic from any source)"
  exit 1
fi
print_status "ok" "NetworkPolicy has proper 'from' clause"

# Verify there's only ONE from item (most restrictive)
FROM_COUNT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o json | jq '.spec.ingress[0].from | length')
if [[ "${FROM_COUNT}" -gt 1 ]]; then
  print_status "fail" "NetworkPolicy has ${FROM_COUNT} from items (should be 1 for least permissive)"
  echo "Multiple from items create OR logic, which is more permissive"
  exit 1
fi
print_status "ok" "NetworkPolicy has single from item (most restrictive)"

# Wait for pods to be ready
echo ""
echo "⏳ Ensuring pods are ready for testing..."
kubectl wait --for=condition=ready pod -l app=frontend -n frontend --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod -l app=backend -n backend --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod -l app=other -n other --timeout=30s &>/dev/null || true

# Give NetworkPolicy time to be enforced
sleep 5

echo ""
echo "🧪 Testing NetworkPolicy enforcement..."

# Get pod names
FRONTEND_POD=$(kubectl get pod -n frontend -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER_POD=$(kubectl get pod -n other -l app=other -o jsonpath='{.items[0].metadata.name}')

if [[ -z "${FRONTEND_POD}" ]]; then
  print_status "fail" "No frontend pod found"
  exit 1
fi

if [[ -z "${OTHER_POD}" ]]; then
  print_status "fail" "No other namespace pod found"
  exit 1
fi

# Test 1: Frontend should be able to access backend
echo "Test 1: Frontend to Backend on port 8080 (should SUCCEED)..."
if kubectl exec -n frontend "${FRONTEND_POD}" -- timeout 2 curl -s backend.backend.svc.cluster.local:8080 &>/dev/null; then
  print_status "ok" "Frontend can access backend (correct)"
else
  print_status "fail" "Frontend CANNOT access backend (should be allowed)"
  echo "The frontend namespace with app=frontend pods should have access to backend:8080"
  exit 1
fi

# Test 2: Other namespace should NOT be able to access backend
echo "Test 2: Other namespace to Backend on port 8080 (should FAIL)..."
if kubectl exec -n other "${OTHER_POD}" -- timeout 2 curl -s backend.backend.svc.cluster.local:8080 &>/dev/null; then
  print_status "fail" "Other namespace CAN access backend (should be blocked)"
  echo "Pods from namespaces other than frontend should NOT have access"
  exit 1
else
  print_status "ok" "Other namespace cannot access backend (correct)"
fi

# Display deployed policy summary
echo ""
echo "📋 Deployed NetworkPolicy summary:"
echo "---"
kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0]}' | jq

echo ""
print_status "ok" "🎉 NetworkPolicy verification passed!"
echo ""
echo "📊 Summary:"
echo "   ✅ Correct NetworkPolicy deployed (policy2.yaml)"
echo "   ✅ Uses BOTH namespaceSelector AND podSelector (AND logic)"
echo "   ✅ Selects frontend namespace with app=frontend pods"
echo "   ✅ Allows only port 8080 (least permissive)"
echo "   ✅ No ipBlock or external access"
echo "   ✅ Frontend pods can access backend"
echo "   ✅ Other namespace pods are blocked"
echo "   ✅ Most restrictive policy correctly identified"
echo ""

exit 0
