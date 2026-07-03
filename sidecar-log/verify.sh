#!/bin/bash
set -euo pipefail

# Check that the new YAML file exists
echo "Checking /opt/course/16/cleaner-new.yaml"

if [[ ! -f /opt/course/16/cleaner-new.yaml ]]; then
  echo "FAIL: /opt/course/16/cleaner-new.yaml does not exist"
  exit 1
fi

# Check that logger-con is in initContainers, not regular containers
if ! grep -q "initContainers:" /opt/course/16/cleaner-new.yaml; then
  echo "FAIL: cleaner-new.yaml must contain initContainers"
  echo "The sidecar should be defined under spec.template.spec.initContainers"
  exit 1
fi

if ! grep -q "name: logger-con" /opt/course/16/cleaner-new.yaml; then
  echo "FAIL: cleaner-new.yaml does not contain a container named logger-con"
  exit 1
fi

# Check that logger-con has restartPolicy: Always
if ! grep -A10 "name: logger-con" /opt/course/16/cleaner-new.yaml | grep -q "restartPolicy: Always"; then
  echo "FAIL: logger-con must have restartPolicy: Always"
  echo "This is required for a restartable sidecar init container"
  exit 1
fi

echo "PASS: cleaner-new.yaml contains logger-con as a restartable init container"

# Check that both containers mount the same volume
CLEANER_VOLUME=$(grep -A10 "name: cleaner-con" /opt/course/16/cleaner-new.yaml | grep "mountPath" | awk '{print $2}' || true)
LOGGER_VOLUME=$(grep -A10 "name: logger-con" /opt/course/16/cleaner-new.yaml | grep "mountPath" | awk '{print $2}' || true)

if [[ -z "${CLEANER_VOLUME}" || -z "${LOGGER_VOLUME}" ]]; then
  echo "FAIL: Both containers must mount a volume"
  exit 1
fi

echo "PASS: Both containers have volumeMounts"

# Check that the deployment is applied in the mercury namespace
if ! kubectl get deployment cleaner -n mercury &>/dev/null; then
  echo "FAIL: Deployment cleaner not found in namespace mercury"
  echo "Apply it with: kubectl apply -f /opt/course/16/cleaner-new.yaml"
  exit 1
fi

echo "PASS: Deployment cleaner exists in namespace mercury"

# Check that the deployment has available replicas
AVAILABLE=$(kubectl get deployment cleaner -n mercury -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
if [[ "${AVAILABLE}" -lt 1 ]]; then
  echo "FAIL: Deployment cleaner has no available replicas"
  exit 1
fi

echo "PASS: Deployment cleaner has ${AVAILABLE} available replica(s)"

# Check that logger-con container exists in the pod
POD_NAME=$(kubectl get pods -n mercury -l app=cleaner -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "${POD_NAME}" ]]; then
  echo "FAIL: No pod found for deployment cleaner in namespace mercury"
  exit 1
fi

if ! kubectl get pod "${POD_NAME}" -n mercury -o jsonpath='{.spec.initContainers[*].name}' | grep -q "logger-con"; then
  echo "FAIL: Pod ${POD_NAME} does not have logger-con in initContainers"
  exit 1
fi

echo "PASS: Pod ${POD_NAME} has logger-con as an init container"

# Check that logs are accessible from the sidecar init container
echo ""
echo "Checking logs from logger-con container..."

LOGS=$(kubectl logs -n mercury "${POD_NAME}" -c logger-con --tail=20 2>/dev/null || echo "")
if [[ -z "${LOGS}" ]]; then
  echo "FAIL: Could not retrieve logs from logger-con container"
  echo "Ensure the container is running and writing to stdout"
  exit 1
fi

echo "PASS: Logs are accessible from logger-con container"

# Show sample logs
echo ""
echo "Sample logs from logger-con:"
echo "${LOGS}" | tail -10

echo ""
echo "Verification passed!"
echo ""
echo "Summary:"
echo "  PASS: /opt/course/16/cleaner-new.yaml exists with logger-con"
echo "  PASS: logger-con is a restartable init container with restartPolicy: Always"
echo "  PASS: Deployment is applied and running in mercury namespace"
echo "  PASS: logger-con container logs are accessible"
echo ""

exit 0
