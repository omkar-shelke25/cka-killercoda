#!/bin/bash
set -euo pipefail

NS="japan-tourism-platform"
DEPLOYMENT="travel-jp-recommender"
REPLICAS=7
TOPOLOGY_KEY="traveljp.io/deployment-domain"
MAX_SKEW=1
MIN_DOMAINS=2

echo "🔍 Verifying TopologySpreadConstraints configuration..."

# Check namespace
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check Deployment existence
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT}' not found in namespace '${NS}'"
  exit 1
fi

# Verify replicas count
REPLICA_COUNT=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.replicas}')
if [[ "${REPLICA_COUNT}" != "${REPLICAS}" ]]; then
  echo "❌ Incorrect replica count: ${REPLICA_COUNT} (expected: ${REPLICAS})"
  exit 1
else
  echo "✅ Replica count verified: ${REPLICAS}"
fi

# Check if topologySpreadConstraints exists
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.topologySpreadConstraints}' | grep -q "maxSkew"; then
  echo "❌ topologySpreadConstraints not configured"
  exit 1
fi

# Verify maxSkew
ACTUAL_MAX_SKEW=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}')
if [[ "${ACTUAL_MAX_SKEW}" != "${MAX_SKEW}" ]]; then
  echo "❌ Incorrect maxSkew: ${ACTUAL_MAX_SKEW} (expected: ${MAX_SKEW})"
  exit 1
else
  echo "✅ maxSkew verified: ${MAX_SKEW}"
fi

# Verify minDomains
ACTUAL_MIN_DOMAINS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].minDomains}')
if [[ "${ACTUAL_MIN_DOMAINS}" != "${MIN_DOMAINS}" ]]; then
  echo "❌ Incorrect minDomains: ${ACTUAL_MIN_DOMAINS} (expected: ${MIN_DOMAINS})"
  exit 1
else
  echo "✅ minDomains verified: ${MIN_DOMAINS}"
fi

# Verify topologyKey
ACTUAL_TOPOLOGY_KEY=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}')
if [[ "${ACTUAL_TOPOLOGY_KEY}" != "${TOPOLOGY_KEY}" ]]; then
  echo "❌ Incorrect topologyKey: ${ACTUAL_TOPOLOGY_KEY} (expected: ${TOPOLOGY_KEY})"
  exit 1
else
  echo "✅ topologyKey verified: ${TOPOLOGY_KEY}"
fi

# Verify whenUnsatisfiable
WHEN_UNSATISFIABLE=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].whenUnsatisfiable}')
if [[ "${WHEN_UNSATISFIABLE}" != "DoNotSchedule" ]]; then
  echo "❌ Incorrect whenUnsatisfiable: ${WHEN_UNSATISFIABLE} (expected: DoNotSchedule)"
  exit 1
else
  echo "✅ whenUnsatisfiable verified: DoNotSchedule"
fi

# Verify labelSelector
LABEL_SELECTOR=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].labelSelector.matchLabels}')
if ! echo "${LABEL_SELECTOR}" | grep -q "app.kubernetes.io/component.*frontend"; then
  echo "❌ labelSelector missing 'app.kubernetes.io/component: frontend'"
  exit 1
fi
if ! echo "${LABEL_SELECTOR}" | grep -q "app.kubernetes.io/version.*v1.0.0"; then
  echo "❌ labelSelector missing 'app.kubernetes.io/version: v1.0.0'"
  exit 1
fi
echo "✅ labelSelector verified with correct labels"

# Wait for Pods to be ready
echo "⏳ Waiting for Pods to be ready..."
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=frontend -n "${NS}" --timeout=60s &>/dev/null; then
  echo "⚠️  Warning: Not all Pods are ready yet, but configuration is correct"
else
  echo "✅ All Pods are ready"
  
  # Check Pod distribution
  CONTROLPLANE_PODS=$(kubectl get pods -n "${NS}" -o wide | grep controlplane | wc -l)
  NODE01_PODS=$(kubectl get pods -n "${NS}" -o wide | grep node01 | wc -l)
  
  echo "📊 Pod Distribution:"
  echo "   controlplane (tokyo-a-server): ${CONTROLPLANE_PODS} Pods"
  echo "   node01 (tokyo-b-server): ${NODE01_PODS} Pods"
  
  # Calculate skew
  SKEW=$((CONTROLPLANE_PODS - NODE01_PODS))
  SKEW=${SKEW#-}  # Absolute value
  
  if [[ ${SKEW} -le ${MAX_SKEW} ]]; then
    echo "✅ Pod distribution satisfies maxSkew constraint (difference: ${SKEW})"
  else
    echo "⚠️  Warning: Pod distribution skew is ${SKEW}, but constraint allows max ${MAX_SKEW}"
  fi
fi

echo "🎉 Verification passed! TopologySpreadConstraints configured correctly!"
exit 0
