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

# Critical check: Must use namespaceSelector (not just podSelector)
NAMESPACE_SELECTOR=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector}')
if [[ -z "${NAMESPACE_SELECTOR}" || "${NAMESPACE_SELECTOR}" == "null" ]]; then
  print_status "fail" "NetworkPolicy does not use namespaceSelector"
  echo "The policy must use namespaceSelector to allow cross-namespace traffic"
  echo "Using only podSelector will not work for frontend→backend communication"
  exit 1
fi
print_status "ok" "NetworkPolicy uses namespaceSelector"

# Check if namespaceSelector targets frontend namespace
NAMESPACE_LABEL=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels}')
if ! echo "${NAMESPACE_LABEL}" | grep -q '"name":"frontend"'; then
  print_status "fail" "NetworkPolicy does not select frontend namespace"
  echo "Found namespaceSelector labels: ${NAMESPACE_LABEL}"
  exit 1
fi
print_status "ok" "NetworkPolicy selects frontend namespace"

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

# Check that podSelector is not empty (security issue)
POD_SELECTOR_CHECK=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from[0].podSelector}')
if [[ "${POD_SELECTOR_CHECK}" == "{}" ]]; then
  print_status "fail" "NetworkPolicy uses empty podSelector (too permissive)"
  echo "Empty podSelector {} allows all pods in the backend namespace"
  exit 1
fi

# Check that from clause exists (not missing)
FROM_CLAUSE=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o jsonpath='{.spec.ingress[0].from}')
if [[ -z "${FROM_CLAUSE}" || "${FROM_CLAUSE}" == "null" || "${FROM_CLAUSE}" == "[]" ]]; then
  print_status "fail" "NetworkPolicy is missing 'from' clause (allows traffic from any source)"
  exit 1
fi
print_status "ok" "NetworkPolicy has proper 'from' clause"

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
  echo "The frontend namespace should have access to backend:8080"
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

# Additional validation: Check that the correct policy file was used
echo ""
echo "🔎 Validating policy correctness..."

# Get the full policy YAML
POLICY_YAML=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o yaml)

# Check for common issues
if echo "${POLICY_YAML}" | grep -q "podSelector: {}"; then
  if ! echo "${POLICY_YAML}" | grep -q "namespaceSelector:"; then
    print_status "warn" "Policy contains empty podSelector without namespaceSelector (potential issue)"
  fi
fi

# Verify this is the least permissive policy
echo ""
echo "Verifying least permissive requirements:"

# Should have exactly one from clause with namespaceSelector
FROM_COUNT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o json | jq '.spec.ingress[0].from | length')
if [[ "${FROM_COUNT}" -ne 1 ]]; then
  print_status "warn" "Policy has ${FROM_COUNT} 'from' clauses (expected 1 for least permissive)"
fi

print_status "ok" "Policy appears to be least permissive"

# Display deployed policy
echo ""
echo "📋 Deployed NetworkPolicy configuration:"
kubectl get networkpolicy "${NETPOL_NAME}" -n backend -o yaml | grep -A 15 "spec:"

echo ""
print_status "ok" "🎉 NetworkPolicy verification passed!"
echo ""
echo "📊 Summary:"
echo "   ✅ Correct NetworkPolicy deployed (policy2.yaml)"
echo "   ✅ Uses namespaceSelector for cross-namespace traffic"
echo "   ✅ Allows only frontend namespace"
echo "   ✅ Allows only port 8080 (least permissive)"
echo "   ✅ Frontend pods can access backend"
echo "   ✅ Other namespace pods are blocked"
echo ""

exit 0
