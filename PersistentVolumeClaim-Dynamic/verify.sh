#!/bin/bash
set -euo pipefail

NS="operations"
PVC_NAME="processor-cache"
DEPLOYMENT_NAME="image-processor"
DEPLOYMENT_FILE="/src/k8s/image-processor.yaml"
EXPECTED_STORAGE="1Gi"
EXPECTED_STORAGECLASS="local-path"
EXPECTED_MOUNT_PATH="/cache"

echo "🔍 Verifying PVC configuration and dynamic provisioning..."

# Check namespace exists
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi
echo "✅ Namespace '${NS}' exists"

# Check PVC exists
if ! kubectl get pvc "${PVC_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ PersistentVolumeClaim '${PVC_NAME}' not found in namespace '${NS}'"
  exit 1
fi
echo "✅ PersistentVolumeClaim '${PVC_NAME}' exists"

# Verify PVC storage request
STORAGE_REQUEST=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.resources.requests.storage}')
if [[ "${STORAGE_REQUEST}" != "${EXPECTED_STORAGE}" ]]; then
  echo "❌ PVC storage request is '${STORAGE_REQUEST}', expected '${EXPECTED_STORAGE}'"
  exit 1
fi
echo "✅ PVC requests ${EXPECTED_STORAGE} of storage"

# Verify PVC uses correct StorageClass
STORAGECLASS=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.storageClassName}')
if [[ "${STORAGECLASS}" != "${EXPECTED_STORAGECLASS}" ]]; then
  echo "❌ PVC uses StorageClass '${STORAGECLASS}', expected '${EXPECTED_STORAGECLASS}'"
  exit 1
fi
echo "✅ PVC uses StorageClass '${EXPECTED_STORAGECLASS}'"

# Check PVC status is Bound
PVC_STATUS=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.status.phase}')
if [[ "${PVC_STATUS}" != "Bound" ]]; then
  echo "❌ PVC status is '${PVC_STATUS}', expected 'Bound'"
  echo "   Tip: The PVC may be pending because no pod is using it yet"
  exit 1
fi
echo "✅ PVC status is 'Bound'"

# Verify a PV was dynamically created
PV_NAME=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.volumeName}')
if [[ -z "${PV_NAME}" ]]; then
  echo "❌ No PersistentVolume bound to PVC '${PVC_NAME}'"
  exit 1
fi
echo "✅ PersistentVolume '${PV_NAME}' dynamically created and bound"

# Check PV exists
if ! kubectl get pv "${PV_NAME}" &>/dev/null; then
  echo "❌ PersistentVolume '${PV_NAME}' not found"
  exit 1
fi
echo "✅ PersistentVolume exists"

# Verify PV uses the correct StorageClass
PV_STORAGECLASS=$(kubectl get pv "${PV_NAME}" -o jsonpath='{.spec.storageClassName}')
if [[ "${PV_STORAGECLASS}" != "${EXPECTED_STORAGECLASS}" ]]; then
  echo "❌ PV uses StorageClass '${PV_STORAGECLASS}', expected '${EXPECTED_STORAGECLASS}'"
  exit 1
fi
echo "✅ PV uses correct StorageClass"

# Check Deployment manifest file exists
if [[ ! -f "${DEPLOYMENT_FILE}" ]]; then
  echo "❌ Deployment manifest file '${DEPLOYMENT_FILE}' not found"
  exit 1
fi
echo "✅ Deployment manifest file exists"

# Check if Deployment manifest contains volume reference
if ! grep -q "volumes:" "${DEPLOYMENT_FILE}"; then
  echo "❌ Deployment manifest does not contain 'volumes:' section"
  exit 1
fi
echo "✅ Deployment manifest contains volume configuration"

# Check if Deployment manifest references the PVC
if ! grep -q "persistentVolumeClaim:" "${DEPLOYMENT_FILE}"; then
  echo "❌ Deployment manifest does not reference a PersistentVolumeClaim"
  exit 1
fi

if ! grep -q "claimName: ${PVC_NAME}" "${DEPLOYMENT_FILE}"; then
  echo "❌ Deployment manifest does not reference PVC '${PVC_NAME}'"
  exit 1
fi
echo "✅ Deployment manifest references PVC '${PVC_NAME}'"

# Check if Deployment manifest contains volumeMount
if ! grep -q "volumeMounts:" "${DEPLOYMENT_FILE}"; then
  echo "❌ Deployment manifest does not contain 'volumeMounts:' section"
  exit 1
fi
echo "✅ Deployment manifest contains volumeMount configuration"

# Check if Deployment manifest mounts at /cache
if ! grep -q "mountPath: ${EXPECTED_MOUNT_PATH}" "${DEPLOYMENT_FILE}"; then
  echo "❌ Deployment manifest does not mount at '${EXPECTED_MOUNT_PATH}'"
  exit 1
fi
echo "✅ Deployment manifest mounts volume at '${EXPECTED_MOUNT_PATH}'"

# Check Deployment exists
if ! kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT_NAME}' not found in namespace '${NS}'"
  exit 1
fi
echo "✅ Deployment '${DEPLOYMENT_NAME}' exists"

# Verify Deployment has volume configured
VOLUME_COUNT=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.volumes}' | grep -c "persistentVolumeClaim" || true)
if [[ "${VOLUME_COUNT}" -lt 1 ]]; then
  echo "❌ Deployment does not have a volume using a PersistentVolumeClaim"
  exit 1
fi
echo "✅ Deployment has volume configured with PVC"

# Verify Deployment references the correct PVC
DEPLOYED_PVC=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}')
if [[ "${DEPLOYED_PVC}" != "${PVC_NAME}" ]]; then
  echo "❌ Deployment references PVC '${DEPLOYED_PVC}', expected '${PVC_NAME}'"
  exit 1
fi
echo "✅ Deployment references correct PVC"

# Check if pod is running
POD_COUNT=$(kubectl get pods -n "${NS}" -l app=image-processor --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [[ "${POD_COUNT}" -lt 1 ]]; then
  echo "❌ No running pods found for Deployment '${DEPLOYMENT_NAME}'"
  exit 1
fi
echo "✅ Pod is running"

# Get the pod name
POD_NAME=$(kubectl get pod -n "${NS}" -l app=image-processor -o jsonpath='{.items[0].metadata.name}')
if [[ -z "${POD_NAME}" ]]; then
  echo "❌ Could not find pod name"
  exit 1
fi
echo "✅ Found pod: ${POD_NAME}"

# Wait for pod to be ready
echo "⏳ Waiting for pod to be ready..."
if ! kubectl wait --for=condition=ready pod/"${POD_NAME}" -n "${NS}" --timeout=60s &>/dev/null; then
  echo "❌ Pod did not become ready in time"
  exit 1
fi
echo "✅ Pod is ready"

# Verify volume is mounted in the pod
MOUNT_PATH=$(kubectl get pod "${POD_NAME}" -n "${NS}" -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="cache-storage")].mountPath}' 2>/dev/null || echo "")
if [[ "${MOUNT_PATH}" != "${EXPECTED_MOUNT_PATH}" ]]; then
  echo "❌ Volume not mounted at '${EXPECTED_MOUNT_PATH}' in pod (found: '${MOUNT_PATH}')"
  exit 1
fi
echo "✅ Volume mounted at '${EXPECTED_MOUNT_PATH}' in pod"

# Test if /cache directory is accessible
if ! kubectl exec -n "${NS}" "${POD_NAME}" -- ls "${EXPECTED_MOUNT_PATH}" &>/dev/null; then
  echo "❌ Cannot access '${EXPECTED_MOUNT_PATH}' directory in pod"
  exit 1
fi
echo "✅ '${EXPECTED_MOUNT_PATH}' directory is accessible in pod"

# Test write capability
TEST_FILE="${EXPECTED_MOUNT_PATH}/verify-test-$(date +%s).txt"
TEST_CONTENT="PVC verification test - $(date)"
if ! kubectl exec -n "${NS}" "${POD_NAME}" -- sh -c "echo '${TEST_CONTENT}' > ${TEST_FILE}" &>/dev/null; then
  echo "❌ Cannot write to '${EXPECTED_MOUNT_PATH}' in pod"
  exit 1
fi
echo "✅ Successfully wrote test file to '${EXPECTED_MOUNT_PATH}'"

# Test read capability
READ_CONTENT=$(kubectl exec -n "${NS}" "${POD_NAME}" -- cat "${TEST_FILE}" 2>/dev/null || echo "")
if [[ "${READ_CONTENT}" != "${TEST_CONTENT}" ]]; then
  echo "❌ Cannot read from '${EXPECTED_MOUNT_PATH}' in pod or content mismatch"
  exit 1
fi
echo "✅ Successfully read test file from '${EXPECTED_MOUNT_PATH}'"

# Clean up test file
kubectl exec -n "${NS}" "${POD_NAME}" -- rm -f "${TEST_FILE}" &>/dev/null || true

echo ""
echo "🎉 Verification passed! PVC configuration and dynamic provisioning completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ PVC '${PVC_NAME}' created with 1Gi storage using '${EXPECTED_STORAGECLASS}' StorageClass"
echo "   ✅ PV '${PV_NAME}' dynamically provisioned and bound"
echo "   ✅ Deployment manifest modified with volume and volumeMount"
echo "   ✅ Pod successfully mounts volume at '${EXPECTED_MOUNT_PATH}'"
echo "   ✅ Read/write operations verified on mounted volume"
echo ""

exit 0
