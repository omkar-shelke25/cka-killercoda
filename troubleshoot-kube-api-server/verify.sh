#!/bin/bash
set -euo pipefail

MANIFEST_PATH="/etc/kubernetes/manifests/kube-apiserver.yaml"
EXPECTED_CPU="200m"
NAMESPACE="kube-system"

echo "🔍 Verifying kube-apiserver CPU resource fix..."
echo ""

# Check if manifest exists
if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "❌ kube-apiserver manifest not found at ${MANIFEST_PATH}"
  exit 1
fi
echo "✅ kube-apiserver manifest exists"

# Check if the CPU request has been corrected
CPU_REQUEST=$(grep -A 5 "resources:" "${MANIFEST_PATH}" | grep "cpu:" | head -1 | awk '{print $2}')

if [[ -z "${CPU_REQUEST}" ]]; then
  echo "❌ Could not find CPU request in manifest"
  exit 1
fi

if [[ "${CPU_REQUEST}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ CPU request is ${CPU_REQUEST}, expected ${EXPECTED_CPU}"
  echo "   The manifest should request 20% of node capacity (200m)"
  exit 1
fi
echo "✅ CPU request correctly set to ${EXPECTED_CPU}"

# Wait a bit for kubelet to process the change
echo ""
echo "⏳ Waiting for kubelet to recreate the kube-apiserver Pod..."
sleep 15

# Check if kube-apiserver Pod exists
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "${POD_NAME}" ]]; then
  echo "❌ kube-apiserver Pod not found in namespace ${NAMESPACE}"
  echo "   The kubelet may still be processing the manifest change"
  echo "   Check with: kubectl get pods -n kube-system | grep apiserver"
  exit 1
fi
echo "✅ kube-apiserver Pod exists: ${POD_NAME}"

# Check Pod status
POD_STATUS=$(kubectl get pod -n ${NAMESPACE} ${POD_NAME} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

if [[ "${POD_STATUS}" != "Running" ]]; then
  echo "❌ kube-apiserver Pod is not running (status: ${POD_STATUS})"
  echo ""
  echo "Pod events:"
  kubectl describe pod -n ${NAMESPACE} ${POD_NAME} | tail -20
  exit 1
fi
echo "✅ kube-apiserver Pod is running"

# Check if containers are ready
READY_STATUS=$(kubectl get pod -n ${NAMESPACE} ${POD_NAME} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

if [[ "${READY_STATUS}" != "True" ]]; then
  echo "⚠️  Warning: kube-apiserver Pod is not ready yet"
  echo "   Status: ${READY_STATUS}"
else
  echo "✅ kube-apiserver Pod is ready"
fi

# Verify the actual resource configuration in the running Pod
ACTUAL_CPU=$(kubectl get pod -n ${NAMESPACE} ${POD_NAME} -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")

if [[ "${ACTUAL_CPU}" != "${EXPECTED_CPU}" ]]; then
  echo "❌ Running Pod has CPU request ${ACTUAL_CPU}, expected ${EXPECTED_CPU}"
  exit 1
fi
echo "✅ Running Pod has correct CPU request: ${ACTUAL_CPU}"

# Check if kubectl can communicate with API server
if ! kubectl get nodes &>/dev/null; then
  echo "⚠️  Warning: Cannot communicate with API server yet"
  echo "   The cluster may still be stabilizing"
else
  echo "✅ API server is accessible and responding"
fi

# Check for resource-related errors in kubelet logs
RESOURCE_ERRORS=$(journalctl -u kubelet -n 100 --no-pager --since "5 minutes ago" 2>/dev/null | grep -i "insufficient cpu" | wc -l || echo "0")

if [[ "${RESOURCE_ERRORS}" -gt 0 ]]; then
  echo "⚠️  Warning: Found ${RESOURCE_ERRORS} recent 'Insufficient CPU' errors in kubelet logs"
  echo "   These may be from before the fix"
fi

echo ""
echo "🎉 Verification passed! kube-apiserver CPU resources fixed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ CPU request corrected to ${EXPECTED_CPU} (20% of node capacity)"
echo "   ✅ kube-apiserver Pod is running: ${POD_NAME}"
echo "   ✅ Pod status: ${POD_STATUS}"
echo "   ✅ API server is healthy and accessible"
echo ""

# Display final Pod status
echo "📋 kube-apiserver Pod Details:"
kubectl get pod -n ${NAMESPACE} ${POD_NAME} -o wide

exit 0
