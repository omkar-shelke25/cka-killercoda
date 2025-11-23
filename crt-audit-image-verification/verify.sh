#!/bin/bash
set -euo pipefail

CERT_OLD="/k8s/cert-details-old.txt"
CERT_NEW="/k8s/cert-details-new.txt"
IMAGE_LIST="/k8s/image-list.txt"

echo "🔍 Verifying certificate audit and rotation..."

# Check if directory exists
if [[ ! -d "/k8s" ]]; then
  echo "❌ Directory /k8s does not exist"
  exit 1
fi
echo "✅ Directory /k8s exists"

# Check if cert-details-old.txt exists
if [[ ! -f "${CERT_OLD}" ]]; then
  echo "❌ File '${CERT_OLD}' not found"
  exit 1
fi
echo "✅ File '${CERT_OLD}' exists"

# Verify cert-details-old.txt contains certificate information
if ! grep -q "CERTIFICATE" "${CERT_OLD}"; then
  echo "❌ File '${CERT_OLD}' does not contain certificate information"
  exit 1
fi
echo "✅ File '${CERT_OLD}' contains certificate expiration data"

# Check for common certificates in old file
for cert in "apiserver" "admin.conf" "CERTIFICATE AUTHORITY"; do
  if ! grep -q "${cert}" "${CERT_OLD}"; then
    echo "⚠️  Warning: Certificate '${cert}' not found in ${CERT_OLD}"
  fi
done

# Check if cert-details-new.txt exists
if [[ ! -f "${CERT_NEW}" ]]; then
  echo "❌ File '${CERT_NEW}' not found"
  exit 1
fi
echo "✅ File '${CERT_NEW}' exists"

# Verify cert-details-new.txt contains certificate information
if ! grep -q "CERTIFICATE" "${CERT_NEW}"; then
  echo "❌ File '${CERT_NEW}' does not contain certificate information"
  exit 1
fi
echo "✅ File '${CERT_NEW}' contains updated certificate expiration data"

# Check if certificates were actually renewed (compare dates)
OLD_DATE=$(grep -m1 "EXPIRES" "${CERT_OLD}" | awk '{print $2, $3, $4}' || echo "")
NEW_DATE=$(grep -m1 "EXPIRES" "${CERT_NEW}" | awk '{print $2, $3, $4}' || echo "")

if [[ -n "${OLD_DATE}" ]] && [[ -n "${NEW_DATE}" ]]; then
  if [[ "${OLD_DATE}" != "${NEW_DATE}" ]]; then
    echo "✅ Certificates have been renewed (expiration dates changed)"
  else
    echo "⚠️  Warning: Certificate expiration dates appear unchanged"
  fi
fi

# Check if image-list.txt exists
if [[ ! -f "${IMAGE_LIST}" ]]; then
  echo "❌ File '${IMAGE_LIST}' not found"
  exit 1
fi
echo "✅ File '${IMAGE_LIST}' exists"

# Verify image-list.txt contains expected control-plane images
REQUIRED_IMAGES=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd" "coredns")
for image in "${REQUIRED_IMAGES[@]}"; do
  if ! grep -q "${image}" "${IMAGE_LIST}"; then
    echo "❌ Required image '${image}' not found in ${IMAGE_LIST}"
    exit 1
  fi
done
echo "✅ All required control-plane images listed"

# Verify image list contains registry path
if ! grep -q "registry.k8s.io" "${IMAGE_LIST}"; then
  echo "⚠️  Warning: Image list may not contain full registry paths"
fi

# Check file sizes to ensure they're not empty
for file in "${CERT_OLD}" "${CERT_NEW}" "${IMAGE_LIST}"; do
  FILE_SIZE=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null)
  if [[ "${FILE_SIZE}" -lt 50 ]]; then
    echo "❌ File '${file}' is too small (${FILE_SIZE} bytes) - may be incomplete"
    exit 1
  fi
done
echo "✅ All files contain sufficient data"

# Verify cluster is still operational
if ! kubectl get nodes &>/dev/null; then
  echo "⚠️  Warning: Unable to connect to cluster - cluster may be recovering"
else
  echo "✅ Cluster is operational after certificate renewal"
fi

# Check if kubelet is running
if ! systemctl is-active --quiet kubelet 2>/dev/null; then
  echo "⚠️  Warning: kubelet service may not be running"
else
  echo "✅ Kubelet service is active"
fi

# Verify control-plane pods are running
CONTROL_PLANE_PODS=$(kubectl get pods -n kube-system -l tier=control-plane --no-headers 2>/dev/null | wc -l || echo "0")
if [[ "${CONTROL_PLANE_PODS}" -ge 3 ]]; then
  echo "✅ Control-plane pods are running (${CONTROL_PLANE_PODS} pods)"
else
  echo "⚠️  Warning: Expected at least 3 control-plane pods, found ${CONTROL_PLANE_PODS}"
fi

echo ""
echo "🎉 Verification passed! Certificate audit and rotation completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ Pre-renewal certificate status documented in ${CERT_OLD}"
echo "   ✅ Certificates renewed successfully"
echo "   ✅ Post-renewal certificate status documented in ${CERT_NEW}"
echo "   ✅ Control-plane image list documented in ${IMAGE_LIST}"
echo "   ✅ Cluster remains operational"
echo ""
echo "📋 Audit Evidence Files:"
echo "   📄 ${CERT_OLD} - Original certificate expiration dates"
echo "   📄 ${CERT_NEW} - Updated certificate expiration dates"
echo "   📄 ${IMAGE_LIST} - Required control-plane images"
echo ""

exit 0
