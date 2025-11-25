#!/bin/bash
set -euo pipefail

SC_NAME="openebs-local"
OLD_SC_NAME="local-storage"
MANIFEST_FILE="/internal/openebs-local-sc.yaml"
PROVISIONER="openebs.io/local"

echo "🔍 Verifying OpenEBS StorageClass migration..."

# Check if manifest file exists
if [[ ! -f "${MANIFEST_FILE}" ]]; then
  echo "❌ Manifest file '${MANIFEST_FILE}' not found"
  echo "   Create the StorageClass manifest and save it at this location"
  exit 1
fi
echo "✅ Manifest file '${MANIFEST_FILE}' exists"

# Check if file is not empty
FILE_SIZE=$(stat -c%s "${MANIFEST_FILE}" 2>/dev/null || stat -f%z "${MANIFEST_FILE}" 2>/dev/null)
if [[ "${FILE_SIZE}" -eq 0 ]]; then
  echo "❌ Manifest file is empty"
  exit 1
fi
echo "✅ Manifest file has content (${FILE_SIZE} bytes)"

# Check if the new StorageClass exists
if ! kubectl get storageclass "${SC_NAME}" &>/dev/null; then
  echo "❌ StorageClass '${SC_NAME}' not found"
  echo "   Apply the manifest: kubectl apply -f ${MANIFEST_FILE}"
  exit 1
fi
echo "✅ StorageClass '${SC_NAME}' exists"

# Verify provisioner
ACTUAL_PROVISIONER=$(kubectl get storageclass "${SC_NAME}" -o jsonpath='{.provisioner}')
if [[ "${ACTUAL_PROVISIONER}" != "${PROVISIONER}" ]]; then
  echo "❌ Incorrect provisioner: ${ACTUAL_PROVISIONER} (expected: ${PROVISIONER})"
  exit 1
fi
echo "✅ Provisioner verified: ${PROVISIONER}"

# Verify volumeBindingMode
BINDING_MODE=$(kubectl get storageclass "${SC_NAME}" -o jsonpath='{.volumeBindingMode}')
if [[ "${BINDING_MODE}" != "WaitForFirstConsumer" ]]; then
  echo "❌ Incorrect volumeBindingMode: ${BINDING_MODE} (expected: WaitForFirstConsumer)"
  exit 1
fi
echo "✅ volumeBindingMode verified: WaitForFirstConsumer"

# Verify reclaimPolicy
RECLAIM_POLICY=$(kubectl get storageclass "${SC_NAME}" -o jsonpath='{.reclaimPolicy}')
if [[ "${RECLAIM_POLICY}" != "Delete" ]]; then
  echo "❌ Incorrect reclaimPolicy: ${RECLAIM_POLICY} (expected: Delete)"
  exit 1
fi
echo "✅ reclaimPolicy verified: Delete"

# Verify allowVolumeExpansion
ALLOW_EXPANSION=$(kubectl get storageclass "${SC_NAME}" -o jsonpath='{.allowVolumeExpansion}')
if [[ "${ALLOW_EXPANSION}" != "true" ]]; then
  echo "❌ allowVolumeExpansion not set to true (current: ${ALLOW_EXPANSION})"
  exit 1
fi
echo "✅ allowVolumeExpansion verified: true"

# Check if openebs-local is marked as default
IS_DEFAULT=$(kubectl get storageclass "${SC_NAME}" -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
if [[ "${IS_DEFAULT}" != "true" ]]; then
  echo "❌ StorageClass '${SC_NAME}' is not marked as default"
  echo "   Current annotation value: ${IS_DEFAULT}"
  exit 1
fi
echo "✅ StorageClass '${SC_NAME}' is marked as default"

# Check if old StorageClass is NOT default anymore
if kubectl get storageclass "${OLD_SC_NAME}" &>/dev/null; then
  OLD_IS_DEFAULT=$(kubectl get storageclass "${OLD_SC_NAME}" -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
  if [[ "${OLD_IS_DEFAULT}" == "true" ]]; then
    echo "❌ Old StorageClass '${OLD_SC_NAME}' is still marked as default"
    echo "   Remove the default annotation from this StorageClass"
    exit 1
  fi
  echo "✅ Old StorageClass '${OLD_SC_NAME}' is no longer default"
else
  echo "ℹ️  Old StorageClass '${OLD_SC_NAME}' not found (this is acceptable)"
fi

# Verify that manifest contains the StorageClass definition
if ! grep -q "kind: StorageClass" "${MANIFEST_FILE}"; then
  echo "❌ Manifest file does not contain 'kind: StorageClass'"
  exit 1
fi
echo "✅ Manifest contains valid StorageClass definition"

# Verify manifest contains the correct name
if ! grep -q "name: ${SC_NAME}" "${MANIFEST_FILE}"; then
  echo "❌ Manifest does not contain correct name: ${SC_NAME}"
  exit 1
fi
echo "✅ Manifest contains correct StorageClass name"

# Additional check: Verify the parameters/config annotation exists (driver-specific parameters)
CONFIG_ANNOTATION=$(kubectl get storageclass "${SC_NAME}" -o jsonpath='{.metadata.annotations.cas\.openebs\.io/config}' 2>/dev/null || echo "")
if [[ -n "${CONFIG_ANNOTATION}" ]]; then
  echo "✅ StorageClass includes driver-specific parameters (cas.openebs.io/config)"
else
  echo "ℹ️  Note: Driver-specific parameters annotation not found (optional but recommended)"
fi

# Verify only one default StorageClass exists
DEFAULT_COUNT=$(kubectl get storageclass -o json | jq '[.items[] | select(.metadata.annotations."storageclass.kubernetes.io/is-default-class" == "true")] | length')
if [[ "${DEFAULT_COUNT}" -gt 1 ]]; then
  echo "⚠️  Warning: Multiple default StorageClasses detected (${DEFAULT_COUNT})"
  echo "   Only one StorageClass should be marked as default"
  kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations."storageclass\.kubernetes\.io/is-default-class"
elif [[ "${DEFAULT_COUNT}" -eq 0 ]]; then
  echo "⚠️  Warning: No default StorageClass found"
else
  echo "✅ Exactly one default StorageClass configured"
fi

echo ""
echo "🎉 Verification passed! Storage migration completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ StorageClass 'openebs-local' created with correct configuration"
echo "   ✅ Provisioner: openebs.io/local"
echo "   ✅ Volume binding mode: WaitForFirstConsumer"
echo "   ✅ Reclaim policy: Delete"
echo "   ✅ Volume expansion: Enabled"
echo "   ✅ Set as default StorageClass"
echo "   ✅ Previous default StorageClass updated"
echo "   ✅ Manifest saved at ${MANIFEST_FILE}"
echo ""
echo "Current StorageClasses:"
kubectl get storageclass
echo ""

exit 0
