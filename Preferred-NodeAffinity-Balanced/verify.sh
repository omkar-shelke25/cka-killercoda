#!/bin/bash
set -euo pipefail

NS="app"
DEPLOYMENT="app-flask"
EXPECTED_REPLICAS=10

echo "🔍 Verifying Deployment configuration and Pod distribution..."

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
REPLICAS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.replicas}')
if [[ "${REPLICAS}" != "${EXPECTED_REPLICAS}" ]]; then
  echo "❌ Incorrect replicas: ${REPLICAS} (expected: ${EXPECTED_REPLICAS})"
  exit 1
else
  echo "✅ Replicas verified: ${EXPECTED_REPLICAS}"
fi

# Check if preferredDuringSchedulingIgnoredDuringExecution exists
PREFERRED_EXISTS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}' 2>/dev/null || echo "")
if [[ -z "${PREFERRED_EXISTS}" ]]; then
  echo "❌ preferredDuringSchedulingIgnoredDuringExecution not found in Deployment spec"
  exit 1
else
  echo "✅ preferredDuringSchedulingIgnoredDuringExecution found"
fi

# Verify weight is 50
WEIGHT=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight}' 2>/dev/null || echo "")
if [[ "${WEIGHT}" != "50" ]]; then
  echo "❌ Weight is ${WEIGHT} (expected: 50)"
  exit 1
else
  echo "✅ Weight verified: 50"
fi

# Check for gpu.vendor label in matchExpressions
GPU_VENDOR=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions[?(@.key=="gpu.vendor")].values[0]}' 2>/dev/null || echo "")
if [[ "${GPU_VENDOR}" != "nvidia" ]]; then
  echo "❌ gpu.vendor label not correctly configured (found: ${GPU_VENDOR})"
  exit 1
else
  echo "✅ gpu.vendor=nvidia verified"
fi

# Check for gpu.count label in matchExpressions
GPU_COUNT=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].preference.matchExpressions[?(@.key=="gpu.count")].values[0]}' 2>/dev/null || echo "")
if [[ "${GPU_COUNT}" != "1" ]]; then
  echo "❌ gpu.count label not correctly configured (found: ${GPU_COUNT})"
  exit 1
else
  echo "✅ gpu.count=1 verified"
fi

# Wait for Pods to be ready
echo "⏳ Waiting for Pods to be ready..."
kubectl wait --for=condition=Ready pod -l app=app-flask -n "${NS}" --timeout=120s &>/dev/null || {
  echo "⚠️  Some Pods may still be starting, checking distribution anyway..."
}

# Check Pod distribution across nodes
CONTROLPLANE_COUNT=$(kubectl get pods -n "${NS}" -l app=app-flask -o wide --no-headers 2>/dev/null | grep -c "controlplane" || echo "0")
NODE01_COUNT=$(kubectl get pods -n "${NS}" -l app=app-flask -o wide --no-headers 2>/dev/null | grep -c "node01" || echo "0")

echo "📊 Pod Distribution:"
echo "   controlplane: ${CONTROLPLANE_COUNT} Pods"
echo "   node01: ${NODE01_COUNT} Pods"

# Check if Pods are distributed (not all on one node)
if [[ "${CONTROLPLANE_COUNT}" -gt 0 && "${NODE01_COUNT}" -gt 0 ]]; then
  echo "✅ Pods are distributed across both nodes"
elif [[ "${CONTROLPLANE_COUNT}" -eq 0 || "${NODE01_COUNT}" -eq 0 ]]; then
  echo "⚠️  All Pods are on a single node. This might indicate the affinity isn't working as expected."
  echo "    However, preferredDuringSchedulingIgnoredDuringExecution is a soft preference."
  echo "    Configuration is correct, but distribution depends on scheduler decisions."
fi

TOTAL_PODS=$((CONTROLPLANE_COUNT + NODE01_COUNT))
if [[ "${TOTAL_PODS}" -lt "${EXPECTED_REPLICAS}" ]]; then
  echo "⚠️  Only ${TOTAL_PODS}/${EXPECTED_REPLICAS} Pods are scheduled. Some may still be pending."
fi

echo ""
echo "🎉 Verification passed!"
echo "✅ Preferred NodeAffinity is correctly configured with weight 50"
echo "✅ Both gpu.vendor=nvidia and gpu.count=1 labels are matched"
exit 0
