#!/bin/bash
set -euo pipefail

MANIFEST_PATH="/etc/kubernetes/manifests/kube-apiserver.yaml"

# Check if kube-apiserver manifest exists
if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "❌ kube-apiserver manifest not found at ${MANIFEST_PATH}"
  exit 1
fi
echo "✅ kube-apiserver manifest exists"

# Extract the authorization mode from the manifest
AUTH_MODE=$(grep -- '--authorization-mode' "${MANIFEST_PATH}" | sed 's/.*--authorization-mode=//' | tr -d ' ' || echo "")

if [[ -z "${AUTH_MODE}" ]]; then
  echo "❌ Could not find --authorization-mode flag in manifest"
  exit 1
fi
echo "✅ Found authorization mode configuration: ${AUTH_MODE}"

# Check if AlwaysDeny is present
if ! echo "${AUTH_MODE}" | grep -q "AlwaysDeny"; then
  echo "❌ AlwaysDeny not found in authorization mode"
  echo "   Current: ${AUTH_MODE}"
  exit 1
fi
echo "✅ AlwaysDeny is present in authorization mode"

# Check if AlwaysDeny is at the beginning
if ! echo "${AUTH_MODE}" | grep -q "^AlwaysDeny"; then
  echo "❌ AlwaysDeny is not the first authorization mode"
  echo "   Current: ${AUTH_MODE}"
  echo "   Expected: AlwaysDeny should be first"
  exit 1
fi
echo "✅ AlwaysDeny is the first authorization mode"


# Check if kube-apiserver container is running
APISERVER_RUNNING=$(crictl ps 2>/dev/null | grep -c "kube-apiserver" || echo "0")
if [[ "${APISERVER_RUNNING}" -lt 1 ]]; then
  echo "❌ kube-apiserver container is not running"
  echo "   Checking for errors..."
  crictl ps -a | grep kube-apiserver | head -5
  exit 1
fi
echo "✅ kube-apiserver container is running"



