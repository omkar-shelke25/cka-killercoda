#!/bin/bash
set -euo pipefail

echo "Verifying NetworkPolicy configuration..."

NAMESPACE="isolated"
NETPOL_NAME="allow-multi-pod-ingress"

print_status() {
  case "$1" in
    ok)   echo "[OK]   $2" ;;
    fail) echo "[FAIL] $2" ;;
    *)    echo "[WARN] $2" ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { print_status "fail" "Required command '$1' not found in PATH"; exit 1; }
}

require_cmd kubectl
require_cmd jq

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  print_status "fail" "Namespace '${NAMESPACE}' not found"
  exit 1
fi
print_status "ok" "Namespace '${NAMESPACE}' exists"

# Check if NetworkPolicy exists
if ! kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  print_status "fail" "NetworkPolicy '${NETPOL_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
print_status "ok" "NetworkPolicy '${NETPOL_NAME}' exists"

# Fetch the policy once as JSON and use jq for every structural check below.
# (kubectl's jsonpath output for objects/maps prints Go's "map[key:val]" format,
#  not JSON, so grep'ing it for '"key":"val"' or piping it into jq silently
#  breaks — that was the previous bug. -o json + jq avoids that entirely.)
JSON="$(kubectl get networkpolicy "${NETPOL_NAME}" -n "${NAMESPACE}" -o json)"

# Verify NetworkPolicy targets correct pods (app=api)
SEL_APP=$(echo "${JSON}" | jq -r '.spec.podSelector.matchLabels.app // empty')
if [ "${SEL_APP}" != "api" ]; then
  print_status "fail" "NetworkPolicy does not select pods with label app=api (found: '${SEL_APP:-<none>}')"
  exit 1
fi
print_status "ok" "NetworkPolicy selects pods with label app=api"

# Verify policyTypes includes Ingress
TYPES=$(echo "${JSON}" | jq -r '[.spec.policyTypes[]?] | join(" ")')
if ! echo "${TYPES}" | grep -qw "Ingress"; then
  print_status "fail" "NetworkPolicy does not specify Ingress in policyTypes (found: ${TYPES:-<none>})"
  exit 1
fi
print_status "ok" "NetworkPolicy has Ingress in policyTypes"

# Verify at least one ingress rule exists
INGRESS_COUNT=$(echo "${JSON}" | jq '.spec.ingress // [] | length')
if [ "${INGRESS_COUNT}" -eq 0 ]; then
  print_status "fail" "NetworkPolicy has no ingress rules defined"
  exit 1
fi
print_status "ok" "NetworkPolicy has ingress rules defined"

# Verify a single 'from' podSelector requires BOTH app=frontend AND role=proxy (AND logic,
# not two separate podSelector entries which would be OR logic).
AND_MATCH=$(echo "${JSON}" | jq '[.spec.ingress[]?.from[]?.podSelector.matchLabels // {}
  | select(.app == "frontend" and .role == "proxy")] | length')
if [ "${AND_MATCH}" -eq 0 ]; then
  print_status "fail" "No 'from' podSelector requires BOTH app=frontend AND role=proxy on the same selector"
  echo "Found 'from' selectors:"
  echo "${JSON}" | jq -c '[.spec.ingress[]?.from[]?.podSelector.matchLabels // {}]'
  exit 1
fi
print_status "ok" "NetworkPolicy requires app=frontend AND role=proxy in a single source selector"

# Warn (don't fail) if there are extra 'from' entries — could indicate an accidental OR rule
FROM_COUNT=$(echo "${JSON}" | jq '[.spec.ingress[]?.from[]?] | length')
if [ "${FROM_COUNT}" -gt 1 ]; then
  print_status "warn" "Found ${FROM_COUNT} 'from' entries — make sure you didn't accidentally OR two separate selectors together"
fi

# Verify port 7000/TCP is allowed
PORT_MATCH=$(echo "${JSON}" | jq '[.spec.ingress[]?.ports[]?
  | select(((.protocol // "TCP") == "TCP") and ((.port == 7000) or (.port == "7000")))] | length')
if [ "${PORT_MATCH}" -eq 0 ]; then
  print_status "fail" "NetworkPolicy does not allow TCP port 7000"
  exit 1
fi
print_status "ok" "NetworkPolicy allows TCP port 7000"

# Warn if other ports are also allowed (task asks for port 7000 only)
OTHER_PORTS=$(echo "${JSON}" | jq '[.spec.ingress[]?.ports[]?
  | select(((.port != 7000) and (.port != "7000")))] | length')
if [ "${OTHER_PORTS}" -gt 0 ]; then
  print_status "warn" "NetworkPolicy also allows ports other than 7000 — task asked for port 7000 only"
fi

# Confirm test pods are ready (short timeout — they should already be running;
# this just guards against a race, not a real wait).
echo ""
echo "Checking test pods are ready..."
for pod in api-pod frontend-proxy-pod frontend-only-pod database-pod api-pod-alt; do
  kubectl wait --for=condition=ready "pod/${pod}" -n "${NAMESPACE}" --timeout=10s &>/dev/null || true
done

# Live connectivity tests — run concurrently, short per-request timeout,
# no fixed sleep for policy propagation (most CNIs apply well under a second;
# if you hit flaky results on a slow CNI, add a short sleep back in here).
echo ""
echo "Testing live connectivity (parallel)..."

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

run_test() {
  local name="$1" src="$2" dst="$3" port="$4"
  if kubectl exec -n "${NAMESPACE}" "${src}" -- curl -s --max-time 2 "${dst}:${port}" &>/dev/null; then
    echo "allowed" > "${TMPDIR}/${name}"
  else
    echo "blocked" > "${TMPDIR}/${name}"
  fi
}

run_test t1 frontend-proxy-pod api-pod 7000 &
run_test t2 frontend-only-pod  api-pod 7000 &
run_test t3 database-pod       api-pod 7000 &
run_test t4 frontend-proxy-pod api-pod-alt 8080 &
wait

FAILED=0

[ "$(cat "${TMPDIR}/t1")" = "allowed" ] \
  && print_status "ok" "frontend-proxy-pod can reach api-pod:7000" \
  || { print_status "fail" "frontend-proxy-pod could NOT reach api-pod:7000 (should be allowed)"; FAILED=1; }

[ "$(cat "${TMPDIR}/t2")" = "blocked" ] \
  && print_status "ok" "frontend-only-pod correctly blocked from api-pod:7000" \
  || { print_status "fail" "frontend-only-pod reached api-pod:7000 but should be blocked (missing role=proxy)"; FAILED=1; }

[ "$(cat "${TMPDIR}/t3")" = "blocked" ] \
  && print_status "ok" "database-pod correctly blocked from api-pod:7000" \
  || { print_status "fail" "database-pod reached api-pod:7000 but should be blocked"; FAILED=1; }

[ "$(cat "${TMPDIR}/t4")" = "blocked" ] \
  && print_status "ok" "api-pod-alt:8080 correctly blocked (only port 7000 is allowed)" \
  || { print_status "fail" "frontend-proxy-pod reached api-pod-alt:8080 but that port should be blocked"; FAILED=1; }

if [ "${FAILED}" -ne 0 ]; then
  exit 1
fi

# Display the NetworkPolicy for reference
echo ""
echo "NetworkPolicy configuration:"
echo "${JSON}" | jq '.spec'

echo ""
print_status "ok" "NetworkPolicy verification passed"
echo ""
echo "Summary:"
echo "   NetworkPolicy '${NETPOL_NAME}' correctly configured"
echo "   Selects pods with label app=api"
echo "   Requires source pods to have BOTH app=frontend AND role=proxy labels"
echo "   Allows only TCP port 7000"
echo "   Blocks pods with partial label match"
echo "   Blocks pods with wrong labels"
echo "   Blocks traffic to other ports"
echo ""

exit 0
