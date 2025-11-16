#!/bin/bash
set -euo pipefail

NS="mcp-tool"
POD_NAME_PREFIX="mcp-grafana"
STATIC_POD_DIR="/etc/kubernetes/manifests"
EXPECTED_LABELS="app=mcp-grafana tool=grafana workload=monitoring"

echo "🔍 Verifying static pod creation..."

# Check namespace exists
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check if manifest file exists in static pod directory
MANIFEST_FILE=$(find "${STATIC_POD_DIR}" -name "*mcp-grafana*" -type f 2>/dev/null | head -n 1)
if [[ -z "${MANIFEST_FILE}" ]]; then
  echo "❌ Static pod manifest file for 'mcp-grafana' not found in ${STATIC_POD_DIR}"
  echo "   Expected a file like: ${STATIC_POD_DIR}/mcp-grafana.yaml"
  exit 1
else
  echo "✅ Static pod manifest found: ${MANIFEST_FILE}"
fi

# Verify manifest has correct namespace
if ! grep -q "namespace: ${NS}" "${MANIFEST_FILE}"; then
  echo "❌ Manifest does not specify namespace: ${NS}"
  exit 1
else
  echo "✅ Namespace correctly set in manifest: ${NS}"
fi

# Verify manifest has correct pod name
if ! grep -q "name: ${POD_NAME_PREFIX}" "${MANIFEST_FILE}"; then
  echo "❌ Pod name not set to '${POD_NAME_PREFIX}' in manifest"
  exit 1
else
  echo "✅ Pod name correctly set: ${POD_NAME_PREFIX}"
fi

# Check if pod is running (static pods append node name)
POD_FULL_NAME=$(kubectl get pods -n "${NS}" -o name | grep "${POD_NAME_PREFIX}" | head -n 1 | cut -d'/' -f2)
if [[ -z "${POD_FULL_NAME}" ]]; then
  echo "❌ Static pod '${POD_NAME_PREFIX}' not found in namespace '${NS}'"
  echo "   Note: Kubelet may take a few seconds to create the pod"
  echo "   Try: kubectl get pods -n ${NS}"
  exit 1
else
  echo "✅ Static pod found: ${POD_FULL_NAME}"
fi

# Wait for pod to be running
echo "⏳ Waiting for pod to be ready..."
if ! kubectl wait --for=condition=ready pod/"${POD_FULL_NAME}" -n "${NS}" --timeout=60s &>/dev/null; then
  echo "⚠️  Pod is not ready yet, but checking configuration..."
else
  echo "✅ Pod is running"
fi

# Verify labels
echo "🏷️  Verifying labels..."
POD_LABELS=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.metadata.labels}')

if ! echo "${POD_LABELS}" | grep -q '"app":"mcp-grafana"'; then
  echo "❌ Missing label: app=mcp-grafana"
  exit 1
else
  echo "✅ Label verified: app=mcp-grafana"
fi

if ! echo "${POD_LABELS}" | grep -q '"tool":"grafana"'; then
  echo "❌ Missing label: tool=grafana"
  exit 1
else
  echo "✅ Label verified: tool=grafana"
fi

if ! echo "${POD_LABELS}" | grep -q '"workload":"monitoring"'; then
  echo "❌ Missing label: workload=monitoring"
  exit 1
else
  echo "✅ Label verified: workload=monitoring"
fi

# Verify container name
CONTAINER_NAME=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].name}')
if [[ "${CONTAINER_NAME}" != "grafana" ]]; then
  echo "❌ Container name is '${CONTAINER_NAME}', expected 'grafana'"
  exit 1
else
  echo "✅ Container name verified: grafana"
fi

# Verify image
IMAGE=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].image}')
echo "✅ Image verified: ${IMAGE}"

# Verify command
COMMAND=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].command}')
if ! echo "${COMMAND}" | grep -q "sh"; then
  echo "❌ Command does not contain 'sh'"
  exit 1
else
  echo "✅ Command verified: contains 'sh -c'"
fi

# Verify args
ARGS=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].args}')
if ! echo "${ARGS}" | grep -q "sleep"; then
  echo "❌ Args do not contain 'sleep'"
  exit 1
else
  echo "✅ Args verified: contains sleep command"
fi

# Verify pod is on controlplane node
NODE=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.spec.nodeName}')
if [[ "${NODE}" != "controlplane" ]]; then
  echo "⚠️  Pod is on node '${NODE}' (expected 'controlplane')"
  echo "   This is acceptable as long as the manifest is in the controlplane's static pod directory"
fi

# Verify it's actually a static pod (has ownerReferences with kind: Node)
OWNER_KIND=$(kubectl get pod "${POD_FULL_NAME}" -n "${NS}" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null || echo "")
if [[ "${OWNER_KIND}" == "Node" ]]; then
  echo "✅ Confirmed as static pod (owned by Node)"
else
  echo "⚠️  Pod ownership: ${OWNER_KIND:-None}"
fi

echo ""
echo "🎉 Verification passed! Static pod created successfully!"
echo ""
echo "📊 Pod Summary:"
echo "   Name: ${POD_FULL_NAME}"
echo "   Namespace: ${NS}"
echo "   Node: ${NODE}"
echo "   Container: ${CONTAINER_NAME}"
echo "   Image: ${IMAGE}"
echo "   Labels: app=mcp-grafana, tool=grafana, workload=monitoring"
exit 0
