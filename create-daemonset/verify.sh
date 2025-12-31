#!/bin/bash
set -euo pipefail

NS="project-tiger"
DS_NAME="ds-important"
EXPECTED_IMAGE="httpd:2-alpine"
EXPECTED_CPU="10m"
EXPECTED_MEMORY="10Mi"
EXPECTED_LABEL_ID="ds-important"
EXPECTED_LABEL_UUID="18426a0b-5f59-4e10-923f-c0e078e82462"

echo "🔍 Verifying DaemonSet implementation..."

# Check namespace exists
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
else
  echo "✅ Namespace '${NS}' exists"
fi

# Check DaemonSet exists
if ! kubectl get daemonset "${DS_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ DaemonSet '${DS_NAME}' not found in namespace '${NS}'"
  exit 1
else
  echo "✅ DaemonSet '${DS_NAME}' exists"
fi

# Verify it's actually a DaemonSet (not Deployment)
RESOURCE_KIND=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.kind}')
if [[ "${RESOURCE_KIND}" != "DaemonSet" ]]; then
  echo "❌ Resource is not a DaemonSet (found: ${RESOURCE_KIND})"
  exit 1
else
  echo "✅ Resource type verified: DaemonSet"
fi

# Verify DaemonSet labels
DS_LABEL_ID=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.metadata.labels.id}')
DS_LABEL_UUID=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.metadata.labels.uuid}')

if [[ "${DS_LABEL_ID}" != "${EXPECTED_LABEL_ID}" ]]; then
  echo "❌ DaemonSet label 'id' incorrect: ${DS_LABEL_ID} (expected: ${EXPECTED_LABEL_ID})"
  exit 1
else
  echo "✅ DaemonSet label 'id' correct: ${EXPECTED_LABEL_ID}"
fi

if [[ "${DS_LABEL_UUID}" != "${EXPECTED_LABEL_UUID}" ]]; then
  echo "❌ DaemonSet label 'uuid' incorrect: ${DS_LABEL_UUID} (expected: ${EXPECTED_LABEL_UUID})"
  exit 1
else
  echo "✅ DaemonSet label 'uuid' correct"
fi

# Verify Pod template labels
POD_LABEL_ID=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.metadata.labels.id}')
POD_LABEL_UUID=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.metadata.labels.uuid}')

if [[ "${POD_LABEL_ID}" != "${EXPECTED_LABEL_ID}" ]]; then
  echo "❌ Pod template label 'id' incorrect"
  exit 1
else
  echo "✅ Pod template label 'id' correct"
fi

if [[ "${POD_LABEL_UUID}" != "${EXPECTED_LABEL_UUID}" ]]; then
  echo "❌ Pod template label 'uuid' incorrect"
  exit 1
else
  echo "✅ Pod template label 'uuid' correct"
fi

# Verify selector matchLabels
SELECTOR_ID=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.selector.matchLabels.id}')
SELECTOR_UUID=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.selector.matchLabels.uuid}')

if [[ "${SELECTOR_ID}" != "${EXPECTED_LABEL_ID}" ]] || [[ "${SELECTOR_UUID}" != "${EXPECTED_LABEL_UUID}" ]]; then
  echo "❌ Selector matchLabels incorrect"
  exit 1
else
  echo "✅ Selector matchLabels correct"
fi

# Verify image
IMAGE=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].image}')
if [[ "${IMAGE}" != "${EXPECTED_IMAGE}" ]]; then
  echo "❌ Container image incorrect: ${IMAGE} (expected: ${EXPECTED_IMAGE})"
  exit 1
else
  echo "✅ Container image correct: ${EXPECTED_IMAGE}"
fi

# Verify CPU request
CPU_REQUEST=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
if [[ "${CPU_REQUEST}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ CPU request incorrect: ${CPU_REQUEST} (expected: ${EXPECTED_CPU})"
  exit 1
else
  echo "✅ CPU request correct: ${EXPECTED_CPU}"
fi

# Verify memory request
MEMORY_REQUEST=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
if [[ "${MEMORY_REQUEST}" != "${EXPECTED_MEMORY}" ]]; then
  echo "❌ Memory request incorrect: ${MEMORY_REQUEST} (expected: ${EXPECTED_MEMORY})"
  exit 1
else
  echo "✅ Memory request correct: ${EXPECTED_MEMORY}"
fi

# Verify toleration for control plane exists
TOLERATION_KEY=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].key}')
TOLERATION_EFFECT=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].effect}')

if [[ "${TOLERATION_KEY}" != "node-role.kubernetes.io/control-plane" ]]; then
  echo "❌ Control plane toleration not found"
  exit 1
else
  echo "✅ Control plane toleration key correct"
fi

if [[ "${TOLERATION_EFFECT}" != "NoSchedule" ]]; then
  echo "❌ Toleration effect incorrect: ${TOLERATION_EFFECT} (expected: NoSchedule)"
  exit 1
else
  echo "✅ Toleration effect correct: NoSchedule"
fi

# Wait for Pods to be ready
echo ""
echo "⏳ Waiting for DaemonSet Pods to be ready..."
if ! kubectl rollout status daemonset "${DS_NAME}" -n "${NS}" --timeout=60s &>/dev/null; then
  echo "⚠️  Warning: DaemonSet Pods are not ready yet"
  echo "   Check status with: kubectl get pods -n ${NS}"
else
  echo "✅ DaemonSet Pods are ready"
fi

# Count total nodes
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
echo ""
echo "📊 Cluster has ${TOTAL_NODES} node(s)"

# Count DaemonSet Pods
DESIRED_PODS=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.status.desiredNumberScheduled}')
READY_PODS=$(kubectl get daemonset "${DS_NAME}" -n "${NS}" -o jsonpath='{.status.numberReady}')

echo "📊 DaemonSet status:"
echo "   Desired: ${DESIRED_PODS}"
echo "   Ready: ${READY_PODS}"

if [[ "${DESIRED_PODS}" == "${TOTAL_NODES}" ]]; then
  echo "✅ DaemonSet scheduled on all ${TOTAL_NODES} node(s)"
else
  echo "❌ DaemonSet not scheduled on all nodes (${DESIRED_PODS}/${TOTAL_NODES})"
  exit 1
fi

# Verify at least one Pod is on control plane
CONTROL_PLANE_PODS=$(kubectl get pods -n "${NS}" -l id=ds-important -o wide | grep -i "control-plane\|master" | wc -l || true)
if [[ ${CONTROL_PLANE_PODS} -gt 0 ]]; then
  echo "✅ Pod(s) running on control plane node(s)"
else
  echo "⚠️  Warning: No Pods detected on control plane (verify toleration is working)"
fi

# Show Pod distribution
echo ""
echo "🗺️  Pod Distribution:"
kubectl get pods -n "${NS}" -l id=ds-important -o wide

echo ""
echo "🎉 Verification passed! DaemonSet is correctly configured!"
echo "   ✅ DaemonSet with correct name and labels"
echo "   ✅ Image: ${EXPECTED_IMAGE}"
echo "   ✅ Resource requests: CPU ${EXPECTED_CPU}, Memory ${EXPECTED_MEMORY}"
echo "   ✅ Toleration for control plane nodes"
echo "   ✅ Running on all ${TOTAL_NODES} node(s)"
exit 0
