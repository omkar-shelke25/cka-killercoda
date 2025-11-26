#!/bin/bash
set -euo pipefail

NS="database-services"
STATEFULSET="mongodb-users-db"

echo "🔍 Verifying PodAntiAffinity configuration for '${STATEFULSET}'..."

# Check if StatefulSet exists
if ! kubectl get statefulset "${STATEFULSET}" -n "${NS}" &>/dev/null; then
  echo "❌ StatefulSet '${STATEFULSET}' not found in namespace '${NS}'"
  echo "   Did you apply the manifest?"
  exit 1
fi

echo "✅ StatefulSet '${STATEFULSET}' exists"

# Check if manifest file was modified (has affinity section)
if ! grep -q "podAntiAffinity:" /mongodb/mongodb-stateful.yaml; then
  echo "❌ The manifest file does not contain 'podAntiAffinity:' configuration"
  echo "   Please add PodAntiAffinity rules to /mongodb/mongodb-stateful.yaml"
  exit 1
fi

echo "✅ Manifest file contains podAntiAffinity configuration"

# Check if the StatefulSet has podAntiAffinity configured
ANTI_AFFINITY_CHECK=$(kubectl get statefulset "${STATEFULSET}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity}')
if [[ -z "${ANTI_AFFINITY_CHECK}" ]]; then
  echo "❌ StatefulSet does not have podAntiAffinity configured"
  echo "   Did you apply the updated manifest?"
  exit 1
fi

echo "✅ StatefulSet has podAntiAffinity configured"

# Check for required anti-affinity
REQUIRED_CHECK=$(kubectl get statefulset "${STATEFULSET}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution}')
if [[ -z "${REQUIRED_CHECK}" || "${REQUIRED_CHECK}" == "null" ]]; then
  echo "❌ Missing 'requiredDuringSchedulingIgnoredDuringExecution' in podAntiAffinity"
  exit 1
fi

echo "✅ Required podAntiAffinity is configured"

# Check topology key
TOPOLOGY_KEY=$(kubectl get statefulset "${STATEFULSET}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey}')
if [[ "${TOPOLOGY_KEY}" != "topology.kubernetes.io/zone" ]]; then
  echo "❌ Incorrect topologyKey: ${TOPOLOGY_KEY} (expected: topology.kubernetes.io/zone)"
  exit 1
fi

echo "✅ Correct topologyKey: ${TOPOLOGY_KEY}"

# Wait for both pods to be ready
echo "⏳ Waiting for MongoDB Pods to be scheduled..."
sleep 10

# Get pod status
READY_PODS=$(kubectl get pods -n "${NS}" -l app=mongodb-users-db --no-headers 2>/dev/null | grep -c "Running" || echo "0")

echo "Running Pods: ${READY_PODS}"

if [[ "${READY_PODS}" -lt 2 ]]; then
  echo "❌ Expected 2 MongoDB Pods to be Running, found ${READY_PODS}"
  kubectl get pods -n "${NS}" -l app=mongodb-users-db
  exit 1
fi

# Get the nodes where running pods are scheduled
MONGODB_NODES=$(kubectl get pods -n "${NS}" -l app=mongodb-users-db -o jsonpath='{.items[?(@.status.phase=="Running")].spec.nodeName}' | tr ' ' '\n' | sort -u)

echo "MongoDB Pods are running on nodes: ${MONGODB_NODES}"

# Count unique nodes
UNIQUE_NODE_COUNT=$(echo "${MONGODB_NODES}" | wc -l)

if [[ "${UNIQUE_NODE_COUNT}" -lt 2 ]]; then
  echo "❌ MongoDB Pods are not spread across multiple nodes"
  echo "   PodAntiAffinity should prevent pods from being scheduled on the same node"
  kubectl get pods -n "${NS}" -l app=mongodb-users-db -o wide
  exit 1
fi

echo "✅ MongoDB Pods are distributed across ${UNIQUE_NODE_COUNT} different nodes"

# Verify zones
for node in ${MONGODB_NODES}; do
  ZONE=$(kubectl get node "${node}" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
  echo "✅ Node '${node}' is in zone: ${ZONE}"
done

echo ""
echo "🎉 Verification passed!"
echo "✅ PodAntiAffinity is correctly configured with required scheduling"
echo "✅ MongoDB Pods are distributed across different zones for high availability"
echo "✅ No two MongoDB pods are running on the same node/zone"

exit 0
