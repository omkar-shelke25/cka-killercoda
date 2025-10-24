#!/bin/bash
set -euo pipefail

NS="database-storage"
POD="redis-database"
IMAGE="public.ecr.aws/docker/library/redis:alpine"
LABEL_DISK="ssd"
LABEL_REGION="east"

echo "🔍 Verifying Pod scheduling for '${POD}'..."

# Check namespace
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check Pod existence
if ! kubectl get pod "${POD}" -n "${NS}" &>/dev/null; then
  echo "❌ Pod '${POD}' not found in namespace '${NS}'"
  exit 1
fi

# Verify image
IMAGE_FOUND=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.containers[0].image}')
if [[ "${IMAGE_FOUND}" != "${IMAGE}" ]]; then
  echo "❌ Incorrect image: ${IMAGE_FOUND} (expected: ${IMAGE})"
  exit 1
else
  echo "✅ Image verified: ${IMAGE}"
fi

# Verify node scheduling
NODE=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.nodeName}')
if [[ -z "${NODE}" ]]; then
  echo "❌ Pod not yet scheduled on any node"
  exit 1
else
  echo "✅ Pod scheduled on node: ${NODE}"
fi

# Check node labels
DISK_LABEL=$(kubectl get node "${NODE}" -o jsonpath='{.metadata.labels.disktype}')
REGION_LABEL=$(kubectl get node "${NODE}" -o jsonpath='{.metadata.labels.region}')

if [[ "${DISK_LABEL}" == "${LABEL_DISK}" && "${REGION_LABEL}" == "${LABEL_REGION}" ]]; then
  echo "✅ Node '${NODE}' has required labels disktype=${LABEL_DISK}, region=${LABEL_REGION}"
  echo "🎉 Verification passed!"
  exit 0
else
  echo "❌ Node '${NODE}' does not have required labels."
  echo "    Found disktype=${DISK_LABEL:-<none>}, region=${REGION_LABEL:-<none>}"
  exit 1
fi
