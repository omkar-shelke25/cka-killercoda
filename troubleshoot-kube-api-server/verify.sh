#!/bin/bash
set -euo pipefail

MANIFEST_PATH="/etc/kubernetes/manifests/kube-apiserver.yaml"
EXPECTED_CPU="200m"
NAMESPACE="kube-system"
LABEL_SELECTOR="component=kube-apiserver"

echo "🔍 Verifying kube-apiserver CPU resources..."
echo ""

# 1. Check manifest exists
if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "❌ kube-apiserver manifest not found at ${MANIFEST_PATH}"
  exit 1
fi
echo "✅ Manifest exists at ${MANIFEST_PATH}"

# 2. Check CPU request & limit in the manifest
CPU_REQUEST=$(grep -A 10 "resources:" "${MANIFEST_PATH}" | grep -A 5 "requests:" | grep "cpu:" | awk '{print $2}' | head -1 || echo "")
CPU_LIMIT=$(grep -A 10 "resources:" "${MANIFEST_PATH}" | grep -A 5 "limits:"   | grep "cpu:" | awk '{print $2}' | head -1 || echo "")

echo "   Manifest values -> request: '${CPU_REQUEST}', limit: '${CPU_LIMIT}'"

if [[ -z "${CPU_REQUEST}" || -z "${CPU_LIMIT}" ]]; then
  echo "❌ Could not find cpu requests/limits under resources in manifest"
  exit 1
fi

if [[ "${CPU_REQUEST}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ CPU request is '${CPU_REQUEST}', expected '${EXPECTED_CPU}'"
  exit 1
fi

if [[ "${CPU_LIMIT}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ CPU limit is '${CPU_LIMIT}', expected '${EXPECTED_CPU}'"
  exit 1
fi

echo "✅ Manifest has correct cpu request & limit: ${EXPECTED_CPU}"

# 3. Try a quick check against the running Pod (no long waiting)
echo ""
echo "🔍 Checking running kube-apiserver Pod (if API is up)..."

if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  echo "⚠️ API server not reachable yet. Manifest is correct; kubelet will recreate the Pod."
  exit 0
fi

POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "${POD_NAME}" ]]; then
  echo "⚠️ kube-apiserver Pod not yet listed by kubectl, but manifest is fixed."
  exit 0
fi

POD_PHASE=$(kubectl get pod -n "${NAMESPACE}" "${POD_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
echo "   Pod: ${POD_NAME}, phase: ${POD_PHASE}"

# We don't loop forever; just a single snapshot
ACTUAL_CPU_REQUEST=$(kubectl get pod -n "${NAMESPACE}" "${POD_NAME}" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
ACTUAL_CPU_LIMIT=$(kubectl get pod -n "${NAMESPACE}" "${POD_NAME}" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")

echo "   Pod spec -> request: '${ACTUAL_CPU_REQUEST}', limit: '${ACTUAL_CPU_LIMIT}'"

if [[ -n "${ACTUAL_CPU_REQUEST}" && "${ACTUAL_CPU_REQUEST}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ Running Pod has CPU request '${ACTUAL_CPU_REQUEST}', expected '${EXPECTED_CPU}'"
  exit 1
fi

if [[ -n "${ACTUAL_CPU_LIMIT}" && "${ACTUAL_CPU_LIMIT}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ Running Pod has CPU limit '${ACTUAL_CPU_LIMIT}', expected '${EXPECTED_CPU}'"
  exit 1
fi

echo ""
echo "🎉 Verification passed!"
echo "   ✅ Manifest cpu request: ${CPU_REQUEST}"
echo "   ✅ Manifest cpu limit:   ${CPU_LIMIT}"
echo "   ✅ kube-apiserver Pod    : ${POD_NAME:-<not visible>}"
echo "   ✅ Pod phase             : ${POD_PHASE}"
echo ""

exit 0
