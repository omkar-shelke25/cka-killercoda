#!/bin/bash
set -euo pipefail

NS="jujutsu-high"
DEPLOYMENT="tokyo-jutsu"
HPA="gojo-hpa"
EXPECTED_CPU_LIMIT="512m"
EXPECTED_MEM_LIMIT="512Mi"
EXPECTED_CPU_REQUEST="256m"
EXPECTED_MEM_REQUEST="256Mi"

echo "🔍 Verifying resource configuration for HPA compatibility..."

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

# Check HPA existence
if ! kubectl get hpa "${HPA}" -n "${NS}" &>/dev/null; then
  echo "❌ HPA '${HPA}' not found in namespace '${NS}'"
  exit 1
fi

# Wait for Pods to be ready
echo "⏳ Waiting for Pods to be ready..."
if ! kubectl wait --for=condition=ready pod -l app=tokyo-jutsu -n "${NS}" --timeout=60s &>/dev/null; then
  echo "❌ Pods are not ready"
  exit 1
fi
echo "✅ Pods are ready"

# Get Pod name
POD_NAME=$(kubectl get pods -n "${NS}" -l app=tokyo-jutsu -o jsonpath='{.items[0].metadata.name}')

# Verify CPU requests
ACTUAL_CPU_REQUEST=$(kubectl get pod "${POD_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
if [[ -z "${ACTUAL_CPU_REQUEST}" ]]; then
  echo "❌ CPU requests not configured"
  exit 1
fi

# Convert to millicores for comparison
if [[ "${ACTUAL_CPU_REQUEST}" == *"m" ]]; then
  ACTUAL_CPU_REQUEST_VALUE="${ACTUAL_CPU_REQUEST%m}"
else
  ACTUAL_CPU_REQUEST_VALUE=$((${ACTUAL_CPU_REQUEST%.*} * 1000))
fi

if [[ "${ACTUAL_CPU_REQUEST_VALUE}" != "256" ]]; then
  echo "❌ Incorrect CPU request: ${ACTUAL_CPU_REQUEST} (expected: ${EXPECTED_CPU_REQUEST})"
  exit 1
else
  echo "✅ CPU requests verified: ${EXPECTED_CPU_REQUEST}"
fi

# Verify memory requests
ACTUAL_MEM_REQUEST=$(kubectl get pod "${POD_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].resources.requests.memory}')
if [[ -z "${ACTUAL_MEM_REQUEST}" ]]; then
  echo "❌ Memory requests not configured"
  exit 1
fi

# Convert to Mi for comparison
if [[ "${ACTUAL_MEM_REQUEST}" == *"Mi" ]]; then
  ACTUAL_MEM_REQUEST_VALUE="${ACTUAL_MEM_REQUEST%Mi}"
elif [[ "${ACTUAL_MEM_REQUEST}" == *"Gi" ]]; then
  ACTUAL_MEM_REQUEST_VALUE=$((${ACTUAL_MEM_REQUEST%Gi} * 1024))
else
  # Assume bytes, convert to Mi
  ACTUAL_MEM_REQUEST_VALUE=$((${ACTUAL_MEM_REQUEST} / 1024 / 1024))
fi

if [[ "${ACTUAL_MEM_REQUEST_VALUE}" != "256" ]]; then
  echo "❌ Incorrect memory request: ${ACTUAL_MEM_REQUEST} (expected: ${EXPECTED_MEM_REQUEST})"
  exit 1
else
  echo "✅ Memory requests verified: ${EXPECTED_MEM_REQUEST}"
fi

# Verify CPU limits
ACTUAL_CPU_LIMIT=$(kubectl get pod "${POD_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
if [[ -z "${ACTUAL_CPU_LIMIT}" ]]; then
  echo "❌ CPU limits not configured"
  exit 1
fi

# Convert to millicores for comparison
if [[ "${ACTUAL_CPU_LIMIT}" == *"m" ]]; then
  ACTUAL_CPU_LIMIT_VALUE="${ACTUAL_CPU_LIMIT%m}"
else
  ACTUAL_CPU_LIMIT_VALUE=$((${ACTUAL_CPU_LIMIT%.*} * 1000))
fi

if [[ "${ACTUAL_CPU_LIMIT_VALUE}" != "512" ]]; then
  echo "❌ Incorrect CPU limit: ${ACTUAL_CPU_LIMIT} (expected: ${EXPECTED_CPU_LIMIT})"
  exit 1
else
  echo "✅ CPU limits verified: ${EXPECTED_CPU_LIMIT}"
fi

# Verify memory limits
ACTUAL_MEM_LIMIT=$(kubectl get pod "${POD_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].resources.limits.memory}')
if [[ -z "${ACTUAL_MEM_LIMIT}" ]]; then
  echo "❌ Memory limits not configured"
  exit 1
fi

# Convert to Mi for comparison
if [[ "${ACTUAL_MEM_LIMIT}" == *"Mi" ]]; then
  ACTUAL_MEM_LIMIT_VALUE="${ACTUAL_MEM_LIMIT%Mi}"
elif [[ "${ACTUAL_MEM_LIMIT}" == *"Gi" ]]; then
  ACTUAL_MEM_LIMIT_VALUE=$((${ACTUAL_MEM_LIMIT%Gi} * 1024))
else
  # Assume bytes, convert to Mi
  ACTUAL_MEM_LIMIT_VALUE=$((${ACTUAL_MEM_LIMIT} / 1024 / 1024))
fi

if [[ "${ACTUAL_MEM_LIMIT_VALUE}" != "512" ]]; then
  echo "❌ Incorrect memory limit: ${ACTUAL_MEM_LIMIT} (expected: ${EXPECTED_MEM_LIMIT})"
  exit 1
else
  echo "✅ Memory limits verified: ${EXPECTED_MEM_LIMIT}"
fi

# Verify requests are exactly half of limits
echo "🔍 Verifying requests are exactly half of limits..."

if [[ $((ACTUAL_CPU_REQUEST_VALUE * 2)) != "${ACTUAL_CPU_LIMIT_VALUE}" ]]; then
  echo "❌ CPU requests should be exactly half of limits"
  exit 1
else
  echo "✅ CPU requests are exactly half of limits"
fi

if [[ $((ACTUAL_MEM_REQUEST_VALUE * 2)) != "${ACTUAL_MEM_LIMIT_VALUE}" ]]; then
  echo "❌ Memory requests should be exactly half of limits"
  exit 1
else
  echo "✅ Memory requests are exactly half of limits"
fi

# Verify HPA is not modified
echo "🔍 Verifying HPA configuration..."
HPA_CPU_TARGET=$(kubectl get hpa "${HPA}" -n "${NS}" -o jsonpath='{.spec.metrics[?(@.resource.name=="cpu")].resource.target.averageValue}')
HPA_MEM_TARGET=$(kubectl get hpa "${HPA}" -n "${NS}" -o jsonpath='{.spec.metrics[?(@.resource.name=="memory")].resource.target.averageValue}')

if [[ "${HPA_CPU_TARGET}" != "512m" ]] || [[ "${HPA_MEM_TARGET}" != "512Mi" ]]; then
  echo "❌ HPA configuration was modified (should not be changed)"
  exit 1
else
  echo "✅ HPA configuration unchanged"
fi

echo "📊 Resource Configuration Summary:"
echo "   CPU Requests: ${ACTUAL_CPU_REQUEST} | CPU Limits: ${ACTUAL_CPU_LIMIT}"
echo "   Memory Requests: ${ACTUAL_MEM_REQUEST} | Memory Limits: ${ACTUAL_MEM_LIMIT}"
echo "   HPA Target: CPU ${HPA_CPU_TARGET}, Memory ${HPA_MEM_TARGET}"

echo ""
echo "🎉 Verification passed! Resource configuration is correct and HPA can now calculate metrics!"
exit 0
