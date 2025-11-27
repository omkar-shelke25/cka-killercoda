#!/bin/bash
set -euo pipefail

NS="mysql"
DEPLOYMENT="mysql"
PVC_NAME="mysql-pvc"
PV_NAME="mysql-pv-retain"

echo "🔍 Verifying MySQL Deployment restoration with persistent storage..."

# Check if PVC exists
if ! kubectl get pvc "${PVC_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ PersistentVolumeClaim '${PVC_NAME}' not found in namespace '${NS}'"
  echo "   Did you create the PVC?"
  exit 1
fi

echo "✅ PersistentVolumeClaim '${PVC_NAME}' exists"

# Check PVC status
PVC_STATUS=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.status.phase}')
if [[ "${PVC_STATUS}" != "Bound" ]]; then
  echo "❌ PVC is not bound. Current status: ${PVC_STATUS}"
  echo "   The PVC should be bound to the existing PV"
  kubectl describe pvc "${PVC_NAME}" -n "${NS}"
  exit 1
fi

echo "✅ PVC is bound to a PersistentVolume"

# Check PVC storage request
PVC_STORAGE=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.resources.requests.storage}')
if [[ "${PVC_STORAGE}" != "250Mi" ]]; then
  echo "❌ Incorrect storage request: ${PVC_STORAGE} (expected: 250Mi)"
  exit 1
fi

echo "✅ PVC has correct storage request: ${PVC_STORAGE}"

# Check PVC access mode
PVC_ACCESS_MODE=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.accessModes[0]}')
if [[ "${PVC_ACCESS_MODE}" != "ReadWriteOnce" ]]; then
  echo "❌ Incorrect access mode: ${PVC_ACCESS_MODE} (expected: ReadWriteOnce)"
  exit 1
fi

echo "✅ PVC has correct access mode: ${PVC_ACCESS_MODE}"

# Check PVC storage class
PVC_STORAGE_CLASS=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.storageClassName}')
if [[ "${PVC_STORAGE_CLASS}" != "manual" ]]; then
  echo "❌ Incorrect storageClassName: ${PVC_STORAGE_CLASS} (expected: manual)"
  exit 1
fi

echo "✅ PVC has correct storageClassName: ${PVC_STORAGE_CLASS}"

# Check if PV is bound to the PVC
PV_STATUS=$(kubectl get pv "${PV_NAME}" -o jsonpath='{.status.phase}')
if [[ "${PV_STATUS}" != "Bound" ]]; then
  echo "❌ PersistentVolume is not bound. Current status: ${PV_STATUS}"
  exit 1
fi

PV_CLAIM=$(kubectl get pv "${PV_NAME}" -o jsonpath='{.spec.claimRef.name}')
if [[ "${PV_CLAIM}" != "${PVC_NAME}" ]]; then
  echo "❌ PV is bound to wrong claim: ${PV_CLAIM} (expected: ${PVC_NAME})"
  exit 1
fi

echo "✅ PersistentVolume is bound to the correct PVC"

# Check if Deployment exists
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT}' not found in namespace '${NS}'"
  echo "   Did you apply the Deployment manifest?"
  exit 1
fi

echo "✅ Deployment '${DEPLOYMENT}' exists"

# Check if Deployment manifest has volume configuration
if ! grep -q "volumeMounts:" ~/mysql-deploy.yaml; then
  echo "❌ The Deployment manifest does not contain 'volumeMounts:' configuration"
  echo "   Please add volume mount configuration to ~/mysql-deploy.yaml"
  exit 1
fi

if ! grep -q "volumes:" ~/mysql-deploy.yaml; then
  echo "❌ The Deployment manifest does not contain 'volumes:' configuration"
  echo "   Please add volume configuration to ~/mysql-deploy.yaml"
  exit 1
fi

echo "✅ Deployment manifest contains volume configuration"

# Check if the Deployment has volume configured in the cluster
VOLUME_CHECK=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim.claimName=="mysql")].name}')
if [[ -z "${VOLUME_CHECK}" ]]; then
  echo "❌ Deployment does not have PVC 'mysql' configured as a volume"
  echo "   Did you apply the updated manifest?"
  exit 1
fi

echo "✅ Deployment has PVC configured as a volume"

# Check volume mount path
MOUNT_PATH=$(kubectl get deployment "${DEPLOYMENT}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="'"${VOLUME_CHECK}"'")].mountPath}')
if [[ "${MOUNT_PATH}" != "/var/lib/mysql" ]]; then
  echo "❌ Incorrect mount path: ${MOUNT_PATH} (expected: /var/lib/mysql)"
  exit 1
fi

echo "✅ Volume is mounted at correct path: ${MOUNT_PATH}"

# Wait for Pod to be ready
echo "⏳ Waiting for MySQL Pod to be ready..."
if ! kubectl wait --for=condition=Ready pod -l app=mysql -n "${NS}" --timeout=90s 2>/dev/null; then
  echo "❌ MySQL Pod did not become ready in time"
  echo ""
  echo "Pod status:"
  kubectl get pods -n "${NS}" -l app=mysql
  echo ""
  echo "Pod events:"
  kubectl describe pod -n "${NS}" -l app=mysql | tail -20
  exit 1
fi

echo "✅ MySQL Pod is ready"

# Check if the existing data is accessible
POD_NAME=$(kubectl get pod -n "${NS}" -l app=mysql -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n "${NS}" "${POD_NAME}" -- test -f /var/lib/mysql/movie-booking.sql 2>/dev/null; then
  echo "✅ Existing data is accessible in the Pod"
else
  echo "❌ Existing data file not found in the Pod"
  echo "   The PVC might not be correctly bound to the existing PV"
  exit 1
fi

# Verify data content
DATA_CONTENT=$(kubectl exec -n "${NS}" "${POD_NAME}" -- cat /var/lib/mysql/movie-booking.sql 2>/dev/null || echo "")
if echo "${DATA_CONTENT}" | grep -q "CRITICAL CUSTOMER DATABASE DATA"; then
  echo "✅ Data integrity verified - existing data is preserved"
else
  echo "❌ Data verification failed - existing data may be lost"
  exit 1
fi

echo ""
echo "🎉 Verification passed!"
echo "✅ PersistentVolumeClaim is correctly created and bound"
echo "✅ Deployment is running with persistent storage mounted"
echo "✅ Existing data has been preserved - no data loss!"
echo "✅ MySQL is ready to serve customer requests"

exit 0
