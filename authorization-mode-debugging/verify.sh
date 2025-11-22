#!/bin/bash
# verify.sh - Verify AlwaysDeny is first and API denies requests
set -euo pipefail

MANIFEST_PATH="/etc/kubernetes/manifests/kube-apiserver.yaml"
ERROR_LOG="/root/auth-debug/forbidden-error.txt"
SLEEP_SECONDS=15

# Basic checks
if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "❌ kube-apiserver manifest not found at ${MANIFEST_PATH}"
  exit 1
fi

# Extract --authorization-mode value (robust to spacing)
AUTH_MODE=$(grep -- '--authorization-mode' "${MANIFEST_PATH}" | sed -E 's/.*--authorization-mode=([^ ]*).*/\1/' || echo "")

if [[ -z "${AUTH_MODE}" ]]; then
  echo "❌ --authorization-mode flag not found in ${MANIFEST_PATH}"
  exit 1
fi

# Ensure AlwaysDeny is present and first
if ! echo "${AUTH_MODE}" | grep -q "AlwaysDeny"; then
  echo "❌ AlwaysDeny not present in --authorization-mode (current: ${AUTH_MODE})"
  exit 1
fi

if ! echo "${AUTH_MODE}" | grep -q "^AlwaysDeny"; then
  echo "❌ AlwaysDeny is not the first authorization mode (current: ${AUTH_MODE})"
  exit 1
fi

# Optional warnings for common modes
if ! echo "${AUTH_MODE}" | grep -q "Node"; then
  echo "⚠️  Warning: Node authorization mode not found"
fi
if ! echo "${AUTH_MODE}" | grep -q "RBAC"; then
  echo "⚠️  Warning: RBAC authorization mode not found"
fi

echo "⏳ Waiting ${SLEEP_SECONDS}s for kube-apiserver to restart/stabilize..."
sleep "${SLEEP_SECONDS}"

# Check kube-apiserver running: prefer crictl, fallback to pgrep
APISERVER_RUNNING=0
if command -v crictl >/dev/null 2>&1; then
  APISERVER_RUNNING=$(crictl ps 2>/dev/null | grep -c "kube-apiserver" || echo "0")
else
  APISERVER_RUNNING=$(pgrep -f kube-apiserver | wc -l || echo "0")
fi

if [[ "${APISERVER_RUNNING}" -lt 1 ]]; then
  echo "❌ kube-apiserver does not appear to be running"
  exit 1
fi

# Ensure error log dir exists
mkdir -p "$(dirname "${ERROR_LOG}")"
: > "${ERROR_LOG}" || true

# Helper: run kubectl expecting Forbidden
test_forbidden() {
  local args=("$@")
  local out
  out=$(kubectl "${args[@]}" 2>&1 || true)
  # Save first run output to log for documentation
  if [[ ! -s "${ERROR_LOG}" ]]; then
    printf '%s\n' "${out}" > "${ERROR_LOG}" || true
  fi
  if echo "${out}" | grep -qi "forbidden"; then
    printf "✅ kubectl %s: Forbidden\n" "${args[*]}"
    return 0
  else
    printf "❌ kubectl %s: did not return Forbidden\nOutput:\n%s\n" "${args[*]}" "${out}"
    return 1
  fi
}

FAIL=0
if ! test_forbidden get pods; then FAIL=1; fi
if ! test_forbidden get nodes; then FAIL=1; fi
if ! test_forbidden get namespaces; then FAIL=1; fi

if ! grep -qi "forbidden" "${ERROR_LOG}" 2>/dev/null; then
  echo "⚠️  Warning: ${ERROR_LOG} does not contain a Forbidden message (captured output may differ)"
else
  echo "✅ Forbidden message documented at ${ERROR_LOG}"
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo "❌ One or more API checks failed (did not receive Forbidden as expected)."
  exit 1
fi

echo ""
echo "🎉 Verification complete: AlwaysDeny is first and API requests are denied as expected."
echo "Authorization mode: ${AUTH_MODE}"
echo "Error log: ${ERROR_LOG}"
exit 0
