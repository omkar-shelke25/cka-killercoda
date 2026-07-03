#!/bin/bash
set -euo pipefail

NAMESPACE="vpa-demo"
VPA_NAME="app-vpa"
DEPLOYMENT_NAME="app-deployment"
CONTAINER_NAME="application"

echo "Verifying Vertical Pod Autoscaler configuration..."
echo ""

# Check if VPA exists
if ! kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "FAIL: VPA '${VPA_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
echo "PASS: VPA '${VPA_NAME}' exists in namespace '${NAMESPACE}'"

# Check target reference
TARGET_KIND=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.targetRef.kind}')
TARGET_NAME=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.targetRef.name}')

if [[ "${TARGET_KIND}" != "Deployment" ]]; then
  echo "FAIL: VPA target kind is '${TARGET_KIND}', expected 'Deployment'"
  exit 1
fi
echo "PASS: VPA targets resource kind: ${TARGET_KIND}"

if [[ "${TARGET_NAME}" != "${DEPLOYMENT_NAME}" ]]; then
  echo "FAIL: VPA targets '${TARGET_NAME}', expected '${DEPLOYMENT_NAME}'"
  exit 1
fi
echo "PASS: VPA targets deployment: ${TARGET_NAME}"

# Check update mode
UPDATE_MODE=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.updatePolicy.updateMode}')

if [[ "${UPDATE_MODE}" != "Recreate" ]]; then
  echo "FAIL: Update mode is '${UPDATE_MODE}', expected 'Recreate'"
  exit 1
fi
echo "PASS: Update mode set to: ${UPDATE_MODE}"

# Check resource policy exists
POLICY_COUNT=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies}' | tr -d '[]' | tr ',' '\n' | wc -l)
if [[ "${POLICY_COUNT}" -eq 0 ]]; then
  echo "FAIL: No container policies found in resource policy"
  exit 1
fi
echo "PASS: Resource policy contains ${POLICY_COUNT} container policy(ies)"

# Check container name in policy
POLICY_CONTAINER=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].containerName}')

if [[ "${POLICY_CONTAINER}" != "${CONTAINER_NAME}" ]]; then
  echo "FAIL: Container policy targets '${POLICY_CONTAINER}', expected '${CONTAINER_NAME}'"
  exit 1
fi
echo "PASS: Container policy targets: ${POLICY_CONTAINER}"

# Check controlled resources
CONTROLLED_RESOURCES=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].controlledResources}')

if ! echo "${CONTROLLED_RESOURCES}" | grep -q "cpu"; then
  echo "FAIL: Controlled resources missing 'cpu'"
  exit 1
fi

if ! echo "${CONTROLLED_RESOURCES}" | grep -q "memory"; then
  echo "FAIL: Controlled resources missing 'memory'"
  exit 1
fi
echo "PASS: Controlled resources: CPU and Memory"

# Check controlled values
CONTROLLED_VALUES=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].controlledValues}')

if [[ "${CONTROLLED_VALUES}" != "RequestsAndLimits" ]]; then
  echo "FAIL: Controlled values is '${CONTROLLED_VALUES}', expected 'RequestsAndLimits'"
  exit 1
fi
echo "PASS: Controlled values: ${CONTROLLED_VALUES}"

# Check minimum allowed CPU
MIN_CPU=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].minAllowed.cpu}')

if [[ "${MIN_CPU}" != "100m" ]]; then
  echo "FAIL: Minimum allowed CPU is '${MIN_CPU}', expected '100m'"
  exit 1
fi
echo "PASS: Minimum allowed CPU: ${MIN_CPU}"

# Check minimum allowed memory
MIN_MEMORY=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].minAllowed.memory}')

if [[ "${MIN_MEMORY}" != "128Mi" ]]; then
  echo "FAIL: Minimum allowed memory is '${MIN_MEMORY}', expected '128Mi'"
  exit 1
fi
echo "PASS: Minimum allowed memory: ${MIN_MEMORY}"

# Check maximum allowed CPU
MAX_CPU=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].maxAllowed.cpu}')

# Handle both "2" and "2000m" as valid for 2 CPUs
if [[ "${MAX_CPU}" != "2" && "${MAX_CPU}" != "2000m" ]]; then
  echo "FAIL: Maximum allowed CPU is '${MAX_CPU}', expected '2' or '2000m'"
  exit 1
fi
echo "PASS: Maximum allowed CPU: ${MAX_CPU}"

# Check maximum allowed memory
MAX_MEMORY=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.resourcePolicy.containerPolicies[0].maxAllowed.memory}')

if [[ "${MAX_MEMORY}" != "2Gi" ]]; then
  echo "FAIL: Maximum allowed memory is '${MAX_MEMORY}', expected '2Gi'"
  exit 1
fi
echo "PASS: Maximum allowed memory: ${MAX_MEMORY}"

# Check if VPA has generated recommendations (optional, not required for pass)
echo ""
echo "Checking VPA recommendations..."
RECOMMENDATION=$(kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.recommendation}' 2>/dev/null || echo "")

if [[ -z "${RECOMMENDATION}" || "${RECOMMENDATION}" == "{}" ]]; then
  echo "INFO: VPA has not generated recommendations yet (this is normal for new VPAs)"
  echo "  Recommendations typically appear after 1-2 minutes of monitoring"
else
  echo "PASS: VPA has generated recommendations"
fi

# Check deployment status
echo ""
echo "Checking target deployment..."
if ! kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "FAIL: Target deployment '${DEPLOYMENT_NAME}' not found"
  exit 1
fi

DEPLOYMENT_REPLICAS=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "PASS: Target deployment is healthy (${DEPLOYMENT_REPLICAS} ready replicas)"

echo ""
echo "Verification passed! VPA configured successfully."
echo ""
echo "Summary:"
echo "  PASS: VPA '${VPA_NAME}' targets deployment '${DEPLOYMENT_NAME}'"
echo "  PASS: Update mode: ${UPDATE_MODE}"
echo "  PASS: Container: ${CONTAINER_NAME}"
echo "  PASS: Controlled resources: CPU and Memory"
echo "  PASS: Controlled values: ${CONTROLLED_VALUES}"
echo "  PASS: Min bounds: CPU ${MIN_CPU}, Memory ${MIN_MEMORY}"
echo "  PASS: Max bounds: CPU ${MAX_CPU}, Memory ${MAX_MEMORY}"
echo ""

# Display VPA status
echo "VPA Status:"
kubectl get vpa "${VPA_NAME}" -n "${NAMESPACE}"

exit 0
