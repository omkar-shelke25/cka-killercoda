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

# Verify NetworkPolicy targets correct pods (app=api)
POD_SELECTOR=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.podSelector.matchLabels}')
if ! echo "${POD_SELECTOR}" | grep -q '"app":"api"'; then
  print_status "fail" "NetworkPolicy does not select pods with label app=api"
  echo "Found podSelector: ${POD_SELECTOR}"
  exit 1
fi
print_status "ok" "NetworkPolicy selects pods with label app=api"

# Verify policyTypes includes Ingress
POLICY_TYPES=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.policyTypes[*]}')
if ! echo "${POLICY_TYPES}" | grep -q "Ingress"; then
  print_status "fail" "NetworkPolicy does not specify Ingress in policyTypes"
  echo "Found policyTypes: ${POLICY_TYPES}"
  exit 1
fi
print_status "ok" "NetworkPolicy has Ingress in policyTypes"

# Verify ingress rule exists
INGRESS_RULES=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.ingress}')
if [[ -z "${INGRESS_RULES}" || "${INGRESS_RULES}" == "null" ]]; then
  print_status "fail" "NetworkPolicy has no ingress rules defined"
  exit 1
fi
print_status "ok" "NetworkPolicy has ingress rules defined"

# Verify source pod selector has app=frontend label
FROM_SELECTOR=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels}')
if ! echo "${FROM_SELECTOR}" | grep -q '"app":"frontend"'; then
  print_status "fail" "NetworkPolicy ingress rule does not require app=frontend label"
  echo "Found from selector: ${FROM_SELECTOR}"
  exit 1
fi
print_status "ok" "NetworkPolicy requires app=frontend label in source pods"

# Verify source pod selector has role=proxy label
if ! echo "${FROM_SELECTOR}" | grep -q '"role":"proxy"'; then
  print_status "fail" "NetworkPolicy ingress rule does not require role=proxy label"
  echo "Found from selector: ${FROM_SELECTOR}"
  exit 1
fi
print_status "ok" "NetworkPolicy requires role=proxy label in source pods"

# Verify port 7000 is specified
PORT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.ingress[0].ports[0].port}')
if [[ "${PORT}" != "7000" ]]; then
  print_status "fail" "NetworkPolicy does not allow port 7000 (found: ${PORT})"
  exit 1
fi
print_status "ok" "NetworkPolicy allows TCP port 7000"

# Verify protocol is TCP
PROTOCOL=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.ingress[0].ports[0].protocol}')
if [[ "${PROTOCOL}" != "TCP" ]]; then
  print_status "fail" "NetworkPolicy protocol is not TCP (found: ${PROTOCOL})"
  exit 1
fi
print_status "ok" "NetworkPolicy protocol is TCP"

# Wait for pods to be ready
echo ""
echo "⏳ Ensuring test pods are ready..."
kubectl wait --for=condition=ready pod/api-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod/frontend-proxy-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod/frontend-only-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true
kubectl wait --for=condition=ready pod/database-pod -n "${NAMESPACE}" --timeout=30s &>/dev/null || true

# Give NetworkPolicy time to be enforced
sleep 3

echo ""
echo "🧪 Testing NetworkPolicy enforcement..."

# Test 1: frontend-proxy-pod should be able to access api-pod:7000
echo "Test 1: Checking access from frontend-proxy-pod (has both labels) to api-pod:7000..."
if kubectl exec -n "${NAMESPACE}" frontend-proxy-pod -- timeout 5 curl -s api-pod:7000 &>/dev/null; then
  print_status "ok" "frontend-proxy-pod CAN access api-pod:7000 (correct - has both required labels)"
else
  print_status "fail" "frontend-proxy-pod CANNOT access api-pod:7000 (should be allowed)"
  echo "This pod has both app=frontend and role=proxy labels and should have access"
  exit 1
fi

# Test 2: frontend-only-pod should NOT be able to access api-pod:7000
echo "Test 2: Checking access from frontend-only-pod (missing role=proxy) to api-pod:7000..."
if kubectl exec -n "${NAMESPACE}" frontend-only-pod -- timeout 5 curl -s api-pod:7000 &>/dev/null; then
  print_status "fail" "frontend-only-pod CAN access api-pod:7000 (should be blocked)"
  echo "This pod only has app=frontend label and should NOT have access"
  exit 1
else
  print_status "ok" "frontend-only-pod CANNOT access api-pod:7000 (correct - missing role=proxy label)"
fi

# Test 3: database-pod should NOT be able to access api-pod:7000
echo "Test 3: Checking access from database-pod (wrong labels) to api-pod:7000..."
if kubectl exec -n "${NAMESPACE}" database-pod -- timeout 5 curl -s api-pod:7000 &>/dev/null; then
  print_status "fail" "database-pod CAN access api-pod:7000 (should be blocked)"
  echo "This pod has app=database label and should NOT have access"
  exit 1
else
  print_status "ok" "database-pod CANNOT access api-pod:7000 (correct - wrong labels)"
fi

# Test 4: frontend-proxy-pod should NOT be able to access api-pod-alt:8080
echo "Test 4: Checking access from frontend-proxy-pod to api-pod-alt:8080 (wrong port)..."
if kubectl exec -n "${NAMESPACE}" frontend-proxy-pod -- timeout 5 curl -s api-pod-alt:8080 &>/dev/null; then
  print_status "fail" "frontend-proxy-pod CAN access api-pod-alt:8080 (should be blocked)"
  echo "Port 8080 should NOT be accessible per NetworkPolicy (only 7000 allowed)"
  exit 1
else
  print_status "ok" "frontend-proxy-pod CANNOT access api-pod-alt:8080 (correct - port not allowed)"
fi

# Verify the NetworkPolicy structure is correct
echo ""
echo "🔎 Verifying NetworkPolicy structure..."

# Check that there's only one ingress rule with one from selector
INGRESS_RULE_COUNT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.ingress}' | jq 'length')
if [[ "${INGRESS_RULE_COUNT}" -ne 1 ]]; then
  print_status "warn" "Expected 1 ingress rule, found ${INGRESS_RULE_COUNT}"
fi

# Check that from selector has exactly 2 labels (app and role)
LABEL_COUNT=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o json | jq '.spec.ingress[0].from[0].podSelector.matchLabels | length')
if [[ "${LABEL_COUNT}" -ne 2 ]]; then
  print_status "warn" "Expected 2 labels in from selector, found ${LABEL_COUNT}"
  print_status "warn" "Make sure both app=frontend AND role=proxy are specified in a SINGLE podSelector"
fi

# Display the NetworkPolicy for reference
echo ""
echo "📋 NetworkPolicy configuration:"
kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o yaml | grep -A 20 "spec:"

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
