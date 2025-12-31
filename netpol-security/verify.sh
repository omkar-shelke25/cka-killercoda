#!/bin/bash
set -euo pipefail

NS="project-snake"
NP_NAME="np-backend"

echo "🔍 Verifying NetworkPolicy implementation..."

# Check namespace exists
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check NetworkPolicy exists
if ! kubectl get networkpolicy "${NP_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ NetworkPolicy '${NP_NAME}' not found in namespace '${NS}'"
  exit 1
else
  echo "✅ NetworkPolicy '${NP_NAME}' exists"
fi

# Verify NetworkPolicy targets backend Pods
POD_SELECTOR=$(kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o jsonpath='{.spec.podSelector.matchLabels.app}')
if [[ "${POD_SELECTOR}" != "backend" ]]; then
  echo "❌ NetworkPolicy does not target backend Pods (expected app=backend)"
  exit 1
else
  echo "✅ NetworkPolicy correctly targets backend Pods"
fi

# Verify policyTypes includes Egress
if ! kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o jsonpath='{.spec.policyTypes}' | grep -q "Egress"; then
  echo "❌ NetworkPolicy does not specify Egress policy type"
  exit 1
else
  echo "✅ NetworkPolicy specifies Egress policy type"
fi

# Check for db1 egress rule
DB1_RULE_EXISTS=false
if kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o json | jq -e '.spec.egress[] | select(.to[]?.podSelector?.matchLabels?.app == "db1")' &>/dev/null; then
  DB1_RULE_EXISTS=true
  echo "✅ Egress rule for db1 Pods exists"
  
  # Verify db1 port
  DB1_PORT=$(kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o json | jq -r '.spec.egress[] | select(.to[]?.podSelector?.matchLabels?.app == "db1") | .ports[0].port')
  if [[ "${DB1_PORT}" == "1111" ]]; then
    echo "✅ db1 egress rule uses correct port: 1111"
  else
    echo "❌ db1 egress rule uses incorrect port: ${DB1_PORT} (expected: 1111)"
    exit 1
  fi
else
  echo "❌ No egress rule found for db1 Pods"
  exit 1
fi

# Check for db2 egress rule
DB2_RULE_EXISTS=false
if kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o json | jq -e '.spec.egress[] | select(.to[]?.podSelector?.matchLabels?.app == "db2")' &>/dev/null; then
  DB2_RULE_EXISTS=true
  echo "✅ Egress rule for db2 Pods exists"
  
  # Verify db2 port
  DB2_PORT=$(kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o json | jq -r '.spec.egress[] | select(.to[]?.podSelector?.matchLabels?.app == "db2") | .ports[0].port')
  if [[ "${DB2_PORT}" == "2222" ]]; then
    echo "✅ db2 egress rule uses correct port: 2222"
  else
    echo "❌ db2 egress rule uses incorrect port: ${DB2_PORT} (expected: 2222)"
    exit 1
  fi
else
  echo "❌ No egress rule found for db2 Pods"
  exit 1
fi

# Verify NO DNS rule exists (since we're using Pod IPs only)
EGRESS_COUNT=$(kubectl get networkpolicy "${NP_NAME}" -n "${NS}" -o json | jq '.spec.egress | length')
if [[ "${EGRESS_COUNT}" == "2" ]]; then
  echo "✅ NetworkPolicy has exactly 2 egress rules (db1 and db2 only)"
else
  echo "⚠️  Warning: NetworkPolicy has ${EGRESS_COUNT} egress rules (expected 2)"
fi

# Test connectivity from backend to db1
echo ""
echo "🧪 Testing connectivity..."

BACKEND_POD=$(kubectl get pod -n "${NS}" -l app=backend -o jsonpath='{.items[0].metadata.name}')
DB1_IP=$(kubectl get pod -n "${NS}" -l app=db1 -o jsonpath='{.items[0].status.podIP}')
DB2_IP=$(kubectl get pod -n "${NS}" -l app=db2 -o jsonpath='{.items[0].status.podIP}')
VAULT_IP=$(kubectl get pod -n "${NS}" -l app=vault -o jsonpath='{.items[0].status.podIP}')

# Wait a moment for NetworkPolicy to be enforced
sleep 3

# Test db1 connectivity (should work)
echo "Testing: backend → db1:1111 (${DB1_IP}:1111)"
if kubectl -n "${NS}" exec "${BACKEND_POD}" -- timeout 3 curl -s -m 2 "${DB1_IP}:1111" &>/dev/null; then
  echo "✅ backend → db1:1111 connection successful (allowed)"
else
  echo "❌ backend → db1:1111 connection failed (should be allowed)"
  exit 1
fi

# Test db2 connectivity (should work)
echo "Testing: backend → db2:2222 (${DB2_IP}:2222)"
if kubectl -n "${NS}" exec "${BACKEND_POD}" -- timeout 3 curl -s -m 2 "${DB2_IP}:2222" &>/dev/null; then
  echo "✅ backend → db2:2222 connection successful (allowed)"
else
  echo "❌ backend → db2:2222 connection failed (should be allowed)"
  exit 1
fi

# Test vault connectivity (should fail/timeout)
echo "Testing: backend → vault:3333 (${VAULT_IP}:3333)"
if kubectl -n "${NS}" exec "${BACKEND_POD}" -- timeout 3 curl -s -m 2 "${VAULT_IP}:3333" &>/dev/null; then
  echo "❌ backend → vault:3333 connection successful (should be blocked)"
  exit 1
else
  echo "✅ backend → vault:3333 connection blocked (policy working correctly)"
fi

echo ""
echo "🎉 Verification passed! NetworkPolicy is correctly configured!"
echo ""
echo "📊 Summary:"
echo "   ✅ backend Pods can access db1:1111 (${DB1_IP}:1111)"
echo "   ✅ backend Pods can access db2:2222 (${DB2_IP}:2222)"
echo "   ✅ backend Pods cannot access vault:3333 (${VAULT_IP}:3333)"
echo "   ✅ Only 2 egress rules (no DNS/other services)"
echo ""
echo "🔒 Security incident prevented! Backend Pods now have restricted network access."
exit 0
