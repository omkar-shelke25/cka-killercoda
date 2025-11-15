#!/bin/bash
set -euo pipefail

NS="nara"
BACKEND_DEPLOY="nara-backend"
FRONTEND_DEPLOY="nara-frontend"

echo "🔍 Verifying PodAffinity configuration for '${BACKEND_DEPLOY}'..."

# Check if backend deployment exists
if ! kubectl get deployment "${BACKEND_DEPLOY}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${BACKEND_DEPLOY}' not found in namespace '${NS}'"
  echo "   Did you apply the manifest?"
  exit 1
fi

echo "✅ Deployment '${BACKEND_DEPLOY}' exists"

# Check if manifest file was modified (has affinity section)
if ! grep -q "podAffinity:" /nara.io/nara-backend.yaml; then
  echo "❌ The manifest file does not contain 'podAffinity:' configuration"
  echo "   Please add PodAffinity rules to /nara.io/nara-backend.yaml"
  exit 1
fi

echo "✅ Manifest file contains podAffinity configuration"

# Check if the deployment has podAffinity configured
AFFINITY_CHECK=$(kubectl get deployment "${BACKEND_DEPLOY}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAffinity}')
if [[ -z "${AFFINITY_CHECK}" ]]; then
  echo "❌ Deployment does not have podAffinity configured"
  echo "   Did you apply the updated manifest?"
  exit 1
fi

echo "✅ Deployment has podAffinity configured"

# Check for required affinity
REQUIRED_CHECK=$(kubectl get deployment "${BACKEND_DEPLOY}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution}')
if [[ -z "${REQUIRED_CHECK}" || "${REQUIRED_CHECK}" == "null" ]]; then
  echo "❌ Missing 'requiredDuringSchedulingIgnoredDuringExecution' in podAffinity"
  exit 1
fi

echo "✅ Required podAffinity is configured"

# Check topology key
TOPOLOGY_KEY=$(kubectl get deployment "${BACKEND_DEPLOY}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey}')
if [[ "${TOPOLOGY_KEY}" != "nara.io/zone" ]]; then
  echo "❌ Incorrect topologyKey: ${TOPOLOGY_KEY} (expected: nara.io/zone)"
  exit 1
fi

echo "✅ Correct topologyKey: ${TOPOLOGY_KEY}"

# Wait for backend pods to be scheduled
echo "⏳ Waiting for backend Pods to be scheduled..."
kubectl wait --for=condition=Ready pod -l app=nara-backend -n "${NS}" --timeout=60s || {
  echo "❌ Backend Pods did not become ready in time"
  kubectl get pods -n "${NS}" -l app=nara-backend
  exit 1
}

# Get frontend and backend pod nodes
FRONTEND_NODES=$(kubectl get pods -n "${NS}" -l app=nara-frontend -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u)
BACKEND_NODES=$(kubectl get pods -n "${NS}" -l app=nara-backend -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u)

echo "Frontend Pods are on nodes: ${FRONTEND_NODES}"
echo "Backend Pods are on nodes: ${BACKEND_NODES}"

# Check if backend pods are on the same node(s) as frontend
BACKEND_POD_COUNT=$(kubectl get pods -n "${NS}" -l app=nara-backend --no-headers | wc -l)
if [[ "${BACKEND_POD_COUNT}" -lt 3 ]]; then
  echo "❌ Expected 3 backend Pods, found ${BACKEND_POD_COUNT}"
  exit 1
fi

# Verify all backend pods are on controlplane (same as frontend)
for node in ${BACKEND_NODES}; do
  if ! echo "${FRONTEND_NODES}" | grep -q "${node}"; then
    echo "❌ Backend Pod found on node '${node}' which has no frontend Pods"
    echo "   PodAffinity should ensure backend Pods are co-located with frontend Pods"
    exit 1
  fi
done

echo "✅ All backend Pods are co-located with frontend Pods"
echo "✅ Backend Pods are scheduled on nodes: ${BACKEND_NODES}"

# Verify the zone label
for node in ${BACKEND_NODES}; do
  ZONE=$(kubectl get node "${node}" -o jsonpath='{.metadata.labels.nara\.io/zone}')
  echo "✅ Node '${node}' is in zone: ${ZONE}"
done

echo ""
echo "🎉 Verification passed!"
echo "✅ PodAffinity is correctly configured with required scheduling"
echo "✅ All backend Pods are co-located with frontend Pods based on topology key 'nara.io/zone'"

exit 0
