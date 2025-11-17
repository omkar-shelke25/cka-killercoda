#!/bin/bash
set -euo pipefail

NS="iot-sys"
HPA_NAME="sensor-hpa"
DEPLOYMENT="sensor-api"
MIN_REPLICAS=2
MAX_REPLICAS=8
CPU_TARGET=80
MEMORY_TARGET=80
STABILIZATION_WINDOW=5

echo "🔍 Verifying HPA configuration..."

# Check namespace
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check HPA existence
if ! kubectl get hpa "${HPA_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ HPA '${HPA_NAME}' not found in namespace '${NS}'"
  exit 1
else
  echo "✅ HPA '${HPA_NAME}' exists"
fi

# Verify target deployment
TARGET_DEPLOYMENT=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.scaleTargetRef.name}')
if [[ "${TARGET_DEPLOYMENT}" != "${DEPLOYMENT}" ]]; then
  echo "❌ HPA targets wrong deployment: ${TARGET_DEPLOYMENT} (expected: ${DEPLOYMENT})"
  exit 1
else
  echo "✅ HPA targets correct deployment: ${DEPLOYMENT}"
fi

# Verify minReplicas
ACTUAL_MIN=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.minReplicas}')
if [[ "${ACTUAL_MIN}" != "${MIN_REPLICAS}" ]]; then
  echo "❌ Incorrect minReplicas: ${ACTUAL_MIN} (expected: ${MIN_REPLICAS})"
  exit 1
else
  echo "✅ minReplicas verified: ${MIN_REPLICAS}"
fi

# Verify maxReplicas
ACTUAL_MAX=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.maxReplicas}')
if [[ "${ACTUAL_MAX}" != "${MAX_REPLICAS}" ]]; then
  echo "❌ Incorrect maxReplicas: ${ACTUAL_MAX} (expected: ${MAX_REPLICAS})"
  exit 1
else
  echo "✅ maxReplicas verified: ${MAX_REPLICAS}"
fi

# Check for CPU metric
CPU_METRIC=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.metrics[?(@.resource.name=="cpu")].resource.target.averageUtilization}')
if [[ -z "${CPU_METRIC}" ]]; then
  echo "❌ CPU metric not configured"
  exit 1
elif [[ "${CPU_METRIC}" != "${CPU_TARGET}" ]]; then
  echo "❌ Incorrect CPU target: ${CPU_METRIC}% (expected: ${CPU_TARGET}%)"
  exit 1
else
  echo "✅ CPU metric verified: ${CPU_TARGET}% utilization"
fi

# Check for Memory metric
MEMORY_METRIC=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.metrics[?(@.resource.name=="memory")].resource.target.averageUtilization}')
if [[ -z "${MEMORY_METRIC}" ]]; then
  echo "❌ Memory metric not configured"
  exit 1
elif [[ "${MEMORY_METRIC}" != "${MEMORY_TARGET}" ]]; then
  echo "❌ Incorrect memory target: ${MEMORY_METRIC}% (expected: ${MEMORY_TARGET}%)"
  exit 1
else
  echo "✅ Memory metric verified: ${MEMORY_TARGET}% utilization"
fi

# Verify metrics count (should have exactly 2 metrics: CPU and memory)
METRICS_COUNT=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.metrics}' | jq '. | length')
if [[ "${METRICS_COUNT}" != "2" ]]; then
  echo "❌ Expected 2 metrics (CPU and memory), found: ${METRICS_COUNT}"
  exit 1
else
  echo "✅ Both CPU and memory metrics configured"
fi

# Verify scale-down stabilization window
STABILIZATION=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}')
if [[ -z "${STABILIZATION}" ]]; then
  echo "❌ Scale-down stabilization window not configured"
  exit 1
elif [[ "${STABILIZATION}" != "${STABILIZATION_WINDOW}" ]]; then
  echo "❌ Incorrect stabilization window: ${STABILIZATION}s (expected: ${STABILIZATION_WINDOW}s)"
  exit 1
else
  echo "✅ Scale-down stabilization window verified: ${STABILIZATION_WINDOW} seconds"
fi

# Check HPA API version (should be autoscaling/v2)
API_VERSION=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.apiVersion}')
if [[ "${API_VERSION}" != "autoscaling/v2" ]]; then
  echo "⚠️  Warning: HPA uses API version '${API_VERSION}' (recommended: autoscaling/v2)"
fi

# Verify HPA is functional
echo "⏳ Checking HPA status..."
HPA_STATUS=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}' 2>/dev/null || echo "Unknown")

if [[ "${HPA_STATUS}" == "True" ]]; then
  echo "✅ HPA is active and monitoring metrics"
elif [[ "${HPA_STATUS}" == "False" ]]; then
  REASON=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].reason}')
  echo "⚠️  HPA exists but scaling is not active. Reason: ${REASON}"
  echo "   This may be normal if metrics are still being collected."
else
  echo "⚠️  HPA status is unknown. It may still be initializing."
fi

# Display current state
CURRENT_REPLICAS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.replicas}')
echo ""
echo "📊 Current State:"
echo "   Deployment replicas: ${CURRENT_REPLICAS}"
echo "   HPA min/max: ${MIN_REPLICAS}/${MAX_REPLICAS}"
echo ""

echo "🎉 Verification passed! HPA configured correctly!"
exit 0
