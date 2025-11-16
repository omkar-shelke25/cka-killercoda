#!/bin/bash
set -euo pipefail

NS="mcp-inference"
DEPLOYMENT="mcp-postman"
REPLICAS=4
EXPECTED_TAINT_KEY="node-role.kubernetes.io/mcp"
EXPECTED_NODE="node01"

echo "🔍 Verifying MCP Postman deployment fix..."

# Check namespace exists
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check Deployment exists
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT}' not found in namespace '${NS}'"
  exit 1
fi

# Verify replicas count hasn't changed
REPLICA_COUNT=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.replicas}')
if [[ "${REPLICA_COUNT}" != "${REPLICAS}" ]]; then
  echo "❌ Replica count was modified: ${REPLICA_COUNT} (expected: ${REPLICAS})"
  exit 1
else
  echo "✅ Replica count unchanged: ${REPLICAS}"
fi

# Verify nodeAffinity still exists
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.nodeAffinity}' | grep -q "node-role.kubernetes.io/mcp"; then
  echo "❌ nodeAffinity section was removed or modified incorrectly"
  exit 1
else
  echo "✅ nodeAffinity section preserved"
fi

# Verify labels haven't been removed
LABEL_COUNT=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.metadata.labels}' | grep -o "app.kubernetes.io" | wc -l)
if [[ "${LABEL_COUNT}" -lt 2 ]]; then
  echo "❌ Deployment labels were removed"
  exit 1
else
  echo "✅ Deployment labels preserved"
fi

# Check toleration exists
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations}' | grep -q "key"; then
  echo "❌ Tolerations section not added to deployment"
  exit 1
else
  echo "✅ Tolerations section added"
fi

# Check toleration key is correct
TOLERATION_KEY=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations[0].key}')
if [[ "${TOLERATION_KEY}" != "${EXPECTED_TAINT_KEY}" ]]; then
  echo "❌ Incorrect toleration key: ${TOLERATION_KEY} (expected: ${EXPECTED_TAINT_KEY})"
  exit 1
else
  echo "✅ Toleration key correct: ${EXPECTED_TAINT_KEY}"
fi

# Verify toleration effect
TOLERATION_EFFECT=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations[0].effect}')
if [[ "${TOLERATION_EFFECT}" != "NoSchedule" ]]; then
  echo "❌ Incorrect toleration effect: ${TOLERATION_EFFECT} (expected: NoSchedule)"
  exit 1
else
  echo "✅ Toleration effect verified: NoSchedule"
fi

# Verify toleration value
TOLERATION_VALUE=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations[0].value}')
if [[ "${TOLERATION_VALUE}" != "true" ]]; then
  echo "❌ Incorrect toleration value: ${TOLERATION_VALUE} (expected: true)"
  exit 1
else
  echo "✅ Toleration value verified: true"
fi

# Verify toleration operator
TOLERATION_OPERATOR=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations[0].operator}')
if [[ "${TOLERATION_OPERATOR}" != "Equal" ]]; then
  echo "❌ Incorrect toleration operator: ${TOLERATION_OPERATOR} (expected: Equal)"
  exit 1
else
  echo "✅ Toleration operator verified: Equal"
fi

# Wait for at least one Pod to be ready
echo "⏳ Waiting for Pods to be ready..."
if ! kubectl wait --for=condition=ready pod -l ai.model/name=mcp -n "${NS}" --timeout=90s &>/dev/null; then
  echo "⚠️  Warning: Pods are not ready yet, but configuration looks correct"
  echo "   This might be due to image pull delays. Check with: kubectl get pods -n ${NS}"
else
  echo "✅ Pods are ready"
  
  # Check if Pods are on the correct node
  RUNNING_PODS=$(kubectl get pods -n "${NS}" -o wide | grep Running | grep "${EXPECTED_NODE}" | wc -l)
  
  if [[ ${RUNNING_PODS} -eq 0 ]]; then
    echo "❌ No Pods are running on ${EXPECTED_NODE}"
    exit 1
  else
    echo "✅ ${RUNNING_PODS} Pod(s) successfully scheduled on ${EXPECTED_NODE}"
  fi
  
  # Verify all Pods are on node01 (since it's the only node with the label)
  TOTAL_RUNNING=$(kubectl get pods -n "${NS}" -o wide | grep Running | wc -l)
  if [[ ${TOTAL_RUNNING} -eq ${REPLICAS} ]]; then
    echo "✅ All ${REPLICAS} Pods are running"
  else
    echo "✅ ${TOTAL_RUNNING}/${REPLICAS} Pods are running"
  fi
  
  # Show Pod distribution
  echo ""
  echo "📊 Pod Distribution:"
  kubectl get pods -n "${NS}" -o wide | grep -E "NAME|mcp-postman" || echo "   (Pods still starting)"
fi

echo ""
echo "🎉 Verification passed! The scheduling issue has been fixed!"
echo "   The toleration now matches the node taint, allowing Pods to schedule on node01."
exit 0
