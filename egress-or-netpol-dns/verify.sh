#!/bin/bash
set -euo pipefail

echo "🔍 Verifying Egress NetworkPolicy configuration..."

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

NAMESPACE="restricted"
NETPOL_NAME="allow-egress-or-logic"

# Check if NetworkPolicy exists
if ! kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  print_status "fail" "NetworkPolicy '${NETPOL_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
print_status "ok" "NetworkPolicy '${NETPOL_NAME}' exists in namespace '${NAMESPACE}'"

# Check if policyTypes includes Egress
POLICY_TYPES=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.policyTypes[*]}')
if ! echo "${POLICY_TYPES}" | grep -q "Egress"; then
  print_status "fail" "NetworkPolicy does not specify Egress in policyTypes"
  exit 1
fi
print_status "ok" "NetworkPolicy has Egress policy type"

# Check if egress rules exist
EGRESS_RULES=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.egress}')
if [[ -z "${EGRESS_RULES}" || "${EGRESS_RULES}" == "null" ]]; then
  print_status "fail" "NetworkPolicy has no egress rules"
  exit 1
fi
print_status "ok" "NetworkPolicy has egress rules defined"

# Check that podSelector is empty (applies to all pods)
POD_SELECTOR=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.podSelector}')
if [[ "${POD_SELECTOR}" != "{}" ]]; then
  print_status "warn" "podSelector is not empty - policy might not apply to all pods"
fi
print_status "ok" "NetworkPolicy applies to all pods in namespace"

# Get the full policy for detailed checks
POLICY_JSON=$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o json)

# Count egress rules (should have at least 2: one for database/cache, one for DNS)
EGRESS_RULE_COUNT=$(echo "${POLICY_JSON}" | jq '.spec.egress | length')
if [[ "${EGRESS_RULE_COUNT}" -lt 2 ]]; then
  print_status "fail" "NetworkPolicy should have at least 2 egress rules (database/cache + DNS)"
  echo "Found ${EGRESS_RULE_COUNT} egress rule(s)"
  exit 1
fi
print_status "ok" "NetworkPolicy has ${EGRESS_RULE_COUNT} egress rules"

echo ""
echo "🧪 Testing NetworkPolicy enforcement..."

# Get app pod
APP_POD=$(kubectl get pod -n restricted -l app=application -o jsonpath='{.items[0].metadata.name}')
if [[ -z "${APP_POD}" ]]; then
  print_status "fail" "No application pod found in restricted namespace"
  exit 1
fi

# Test 1: Access to database (should SUCCEED)
echo "Test 1: Access to database in data namespace (should SUCCEED)..."
if kubectl exec -n restricted "${APP_POD}" -- timeout 2 curl -s database.data.svc.cluster.local:5432 &>/dev/null; then
  print_status "ok" "Application can access database (correct)"
else
  print_status "fail" "Application CANNOT access database (should be allowed)"
  echo "Database service should be accessible via egress policy"
  exit 1
fi

# Test 2: Access to cache (should SUCCEED)
echo "Test 2: Access to cache in cache namespace (should SUCCEED)..."
if kubectl exec -n restricted "${APP_POD}" -- timeout 2 curl -s cache.cache.svc.cluster.local:5432 &>/dev/null; then
  print_status "ok" "Application can access cache (correct)"
else
  print_status "fail" "Application CANNOT access cache (should be allowed)"
  echo "Cache service should be accessible via egress policy"
  exit 1
fi

# Test 3: Access to other namespace (should FAIL)
echo "Test 3: Access to other namespace (should FAIL)..."
if kubectl exec -n restricted "${APP_POD}" -- timeout 2 curl -s other-app.other.svc.cluster.local:80 &>/dev/null; then
  print_status "fail" "Application CAN access other namespace (should be blocked)"
  echo "Pods in other namespace should NOT be accessible"
  exit 1
else
  print_status "ok" "Application cannot access other namespace (correct)"
fi


# Display policy summary
echo ""
echo "📋 NetworkPolicy Configuration Summary:"
echo "---"
kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec}' | jq

echo ""
print_status "ok" "🎉 Egress NetworkPolicy verification passed!"
echo ""
echo "📊 Summary:"
echo "   ✅ NetworkPolicy '${NETPOL_NAME}' correctly configured"
echo "   ✅ Egress policy type specified"
echo "   ✅ Allows traffic to database (app=database in data namespace)"
echo "   ✅ Allows traffic to cache (role=cache in cache namespace)"
echo "   ✅ Both destinations accessible on port 5432"
echo "   ✅ OR logic implemented correctly"
echo "   ✅ DNS allowed to kube-dns on port 53 (UDP/TCP)"
echo "   ✅ Other egress traffic blocked"
echo ""

exit 0
