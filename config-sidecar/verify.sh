#!/bin/bash
set -euo pipefail

echo "Verifying sidecar container configuration..."

NAMESPACE="production"
DEPLOYMENT_NAME="web-app"

# Check if deployment exists
if ! kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "FAIL: Deployment '${DEPLOYMENT_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
echo "PASS: Deployment '${DEPLOYMENT_NAME}' exists"

# Check replica count is still 2
REPLICA_COUNT=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
if [[ "${REPLICA_COUNT}" != "2" ]]; then
  echo "FAIL: Replica count changed to ${REPLICA_COUNT} (should remain 2)"
  exit 1
fi
echo "PASS: Replica count unchanged (2)"

# Check labels unchanged
APP_LABEL=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.metadata.labels.app}')
if [[ "${APP_LABEL}" != "web-app" ]]; then
  echo "FAIL: App label changed or missing"
  exit 1
fi
echo "PASS: Labels preserved"

# Check selector unchanged
SELECTOR=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.selector.matchLabels.app}')
if [[ "${SELECTOR}" != "web-app" ]]; then
  echo "FAIL: Selector changed"
  exit 1
fi
echo "PASS: Selector unchanged"

# Get deployment containers
CONTAINERS_JSON=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o json)

# Check number of containers (should be 2)
CONTAINER_COUNT=$(echo "${CONTAINERS_JSON}" | jq '.spec.template.spec.containers | length')
if [[ "${CONTAINER_COUNT}" -ne 2 ]]; then
  echo "FAIL: Expected 2 containers, found ${CONTAINER_COUNT}"
  exit 1
fi
echo "PASS: Two containers configured"

# Check application container exists and unchanged
APP_CONTAINER=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "application") | .name')
if [[ "${APP_CONTAINER}" != "application" ]]; then
  echo "FAIL: Application container not found or renamed"
  exit 1
fi
echo "PASS: Application container exists"

# Check application container image not changed
APP_IMAGE=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "application") | .image')
if [[ "${APP_IMAGE}" != "busybox:latest" ]]; then
  echo "FAIL: Application container image changed to ${APP_IMAGE}"
  exit 1
fi
echo "PASS: Application container image unchanged"

# Check log-agent sidecar container exists
LOG_AGENT=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "log-agent") | .name')
if [[ "${LOG_AGENT}" != "log-agent" ]]; then
  echo "FAIL: Sidecar container 'log-agent' not found"
  exit 1
fi
echo "PASS: Sidecar container 'log-agent' exists"

# Check log-agent uses fluentd:latest image
LOG_AGENT_IMAGE=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "log-agent") | .image')
if [[ "${LOG_AGENT_IMAGE}" != "fluentd:latest" ]]; then
  echo "FAIL: Sidecar container image is '${LOG_AGENT_IMAGE}', expected 'fluentd:latest'"
  exit 1
fi
echo "PASS: Sidecar uses fluentd:latest image"

# Check volume exists
VOLUME_NAME=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.volumes[0].name')
if [[ -z "${VOLUME_NAME}" ]]; then
  echo "FAIL: No volume configured"
  exit 1
fi
echo "PASS: Volume '${VOLUME_NAME}' configured"

# Check application container has volume mount
APP_VOLUME_MOUNT=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "application") | .volumeMounts[0].name')
if [[ -z "${APP_VOLUME_MOUNT}" ]]; then
  echo "FAIL: Application container has no volume mount"
  exit 1
fi
echo "PASS: Application container has volume mount"

# Check application container mount path
APP_MOUNT_PATH=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "application") | .volumeMounts[0].mountPath')
if [[ "${APP_MOUNT_PATH}" != "/var/log/app" ]]; then
  echo "FAIL: Application container mount path is '${APP_MOUNT_PATH}', expected '/var/log/app'"
  exit 1
fi
echo "PASS: Application container mounts at /var/log/app"

# Check sidecar has volume mount
SIDECAR_VOLUME_MOUNT=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "log-agent") | .volumeMounts[0].name')
if [[ -z "${SIDECAR_VOLUME_MOUNT}" ]]; then
  echo "FAIL: Sidecar container has no volume mount"
  exit 1
fi
echo "PASS: Sidecar container has volume mount"

# Check sidecar mount path
SIDECAR_MOUNT_PATH=$(echo "${CONTAINERS_JSON}" | jq -r '.spec.template.spec.containers[] | select(.name == "log-agent") | .volumeMounts[0].mountPath')
if [[ "${SIDECAR_MOUNT_PATH}" != "/var/log/app" ]]; then
  echo "FAIL: Sidecar container mount path is '${SIDECAR_MOUNT_PATH}', expected '/var/log/app'"
  exit 1
fi
echo "PASS: Sidecar container mounts at /var/log/app"

# Check both containers mount same volume
if [[ "${APP_VOLUME_MOUNT}" != "${SIDECAR_VOLUME_MOUNT}" ]]; then
  echo "FAIL: Containers mount different volumes"
  echo "Application: ${APP_VOLUME_MOUNT}, Sidecar: ${SIDECAR_VOLUME_MOUNT}"
  exit 1
fi
echo "PASS: Both containers share the same volume"

# Wait for pods to be ready
echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=web-app -n "${NAMESPACE}" --timeout=60s &>/dev/null || true
sleep 5

# Check if pods are running
POD_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l app=web-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [[ "${POD_COUNT}" -lt 1 ]]; then
  echo "FAIL: No running pods found"
  exit 1
fi
echo "PASS: Pods are running"

# Get a pod for testing
POD_NAME=$(kubectl get pod -n "${NAMESPACE}" -l app=web-app -o jsonpath='{.items[0].metadata.name}')
if [[ -z "${POD_NAME}" ]]; then
  echo "FAIL: Could not get pod name"
  exit 1
fi
echo "Testing with pod: ${POD_NAME}"

# Check pod has 2 containers
POD_CONTAINER_COUNT=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o json | jq '.spec.containers | length')
if [[ "${POD_CONTAINER_COUNT}" -ne 2 ]]; then
  echo "FAIL: Pod has ${POD_CONTAINER_COUNT} containers, expected 2"
  exit 1
fi
echo "PASS: Pod has 2 containers"

# Check both containers are running
RUNNING_CONTAINERS=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[?(@.state.running)].name}' | wc -w)
if [[ "${RUNNING_CONTAINERS}" -ne 2 ]]; then
  echo "FAIL: Only ${RUNNING_CONTAINERS} containers running, expected 2"
  kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[*].state}'
  exit 1
fi
echo "PASS: Both containers are running"

# Test log file accessibility from application container
echo ""
echo "Testing log file accessibility..."
if ! kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c application -- test -f /var/log/app/app.log &>/dev/null; then
  echo "FAIL: Log file not found in application container"
  exit 1
fi
echo "PASS: Log file exists in application container"

# Test log file accessibility from sidecar container
if ! kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c log-agent -- test -f /var/log/app/app.log &>/dev/null; then
  echo "FAIL: Log file not accessible in sidecar container"
  exit 1
fi
echo "PASS: Log file accessible in sidecar container"

# Verify log content is being written
LOG_LINES=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c application -- wc -l /var/log/app/app.log 2>/dev/null | awk '{print $1}')
if [[ "${LOG_LINES}" -lt 1 ]]; then
  echo "FAIL: No log content found"
  exit 1
fi
echo "PASS: Log file contains ${LOG_LINES} lines"

# Verify sidecar can read the same content
SIDECAR_LOG_LINES=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c log-agent -- wc -l /var/log/app/app.log 2>/dev/null | awk '{print $1}')
if [[ "${SIDECAR_LOG_LINES}" -ne "${LOG_LINES}" ]]; then
  echo "FAIL: Sidecar sees different log content"
  exit 1
fi
echo "PASS: Sidecar can read shared logs"

# Verify sidecar is running (check its status)
SIDECAR_STATE=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[?(@.name=="log-agent")].state}')
if echo "${SIDECAR_STATE}" | grep -q "running"; then
  echo "PASS: Sidecar container is running"
else
  echo "WARN: Sidecar state: ${SIDECAR_STATE}"
fi

echo ""
echo "SUCCESS: Sidecar container verification passed!"
echo ""
echo "Summary:"
echo "  - Deployment correctly updated"
echo "  - Two containers per pod: application + log-agent"
echo "  - Sidecar uses fluentd:latest image"
echo "  - Volume shared between containers at /var/log/app"
echo "  - Both containers can access log file"
echo "  - Original configuration preserved"
echo "  - ${POD_COUNT} pods running with 2/2 containers ready"
echo ""

exit 0
