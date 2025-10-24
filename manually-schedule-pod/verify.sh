#!/bin/bash
set -euo pipefail

NS="japan"
POD="tokoyo"
EXPECTED_NODE="controlplane"
SVC="tokoyo"
EXPECTED_PORT=80
EXPECTED_NODEPORT=30099
EXPECTED_IMAGE="public.ecr.aws/nginx/nginx:stable-perl"

rc=0

echo "1) Checking namespace '${NS}'..."
if kubectl get namespace "${NS}" >/dev/null 2>&1; then
  echo "Namespace ${NS} exists"
else
  echo "Namespace ${NS} does not exist"
  rc=1
fi

echo ""
echo "2) Checking Pod ${POD} in namespace ${NS}..."
if ! kubectl get pod "${POD}" -n "${NS}" >/dev/null 2>&1; then
  echo "Pod ${POD} not found in namespace ${NS}"
  rc=1
else
  echo "Pod ${POD} found in namespace ${NS}"
  
  # check nodeName
  NODE_NAME="$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)"
  if [ "${NODE_NAME}" = "${EXPECTED_NODE}" ]; then
    echo "Pod ${POD} is scheduled on node '${EXPECTED_NODE}'"
  else
    echo "Pod ${POD} is scheduled on '${NODE_NAME:-<none>}' but expected '${EXPECTED_NODE}'"
    rc=1
  fi

  # check status is Running
  PHASE="$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [ "${PHASE}" = "Running" ]; then
    echo "Pod ${POD} status is Running"
  else
    echo "Pod ${POD} status is '${PHASE:-<unknown>}' (expected Running)"
    rc=1
  fi

  # check container port presence
  PORT_FOUND=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{range .spec.containers[*].ports[*]}{.containerPort}{" "}{end}' 2>/dev/null || true)
  if echo "${PORT_FOUND}" | grep -qw "${EXPECTED_PORT}"; then
    echo "Pod ${POD} exposes containerPort ${EXPECTED_PORT}"
  else
    echo "Pod ${POD} does not expose containerPort ${EXPECTED_PORT} (found: ${PORT_FOUND:-none})"
    rc=1
  fi

  # check image
  IMAGE_FOUND=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  if [ "${IMAGE_FOUND}" = "${EXPECTED_IMAGE}" ]; then
    echo "Pod ${POD} uses correct image '${EXPECTED_IMAGE}'"
  else
    echo "Pod ${POD} uses image '${IMAGE_FOUND:-<none>}' (expected '${EXPECTED_IMAGE}')"
    rc=1
  fi
fi

echo ""
echo "3) Checking Service ${SVC} in namespace ${NS}..."
if ! kubectl get svc "${SVC}" -n "${NS}" >/dev/null 2>&1; then
  echo "Service ${SVC} not found in namespace ${NS}"
  rc=1
else
  echo "Service ${SVC} found in namespace ${NS}"

  # Check type
  SVC_TYPE="$(kubectl get svc "${SVC}" -n "${NS}" -o jsonpath='{.spec.type}' 2>/dev/null || true)"
  if [ "${SVC_TYPE}" = "NodePort" ]; then
    echo "Service ${SVC} is type NodePort"
  else
    echo "Service ${SVC} is type '${SVC_TYPE:-<none>}' (expected NodePort)"
    rc=1
  fi

  # check port / targetPort / nodePort
  SVC_PORT="$(kubectl get svc "${SVC}" -n "${NS}" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
  SVC_TARGETPORT="$(kubectl get svc "${SVC}" -n "${NS}" -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || true)"
  SVC_NODEPORT="$(kubectl get svc "${SVC}" -n "${NS}" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)"

  if [ "${SVC_PORT}" -eq "${EXPECTED_PORT}" ] 2>/dev/null; then
    echo "Service port is ${EXPECTED_PORT}"
  else
    echo "Service port is '${SVC_PORT:-<none>}' (expected ${EXPECTED_PORT})"
    rc=1
  fi

  if [ "${SVC_TARGETPORT}" = "${EXPECTED_PORT}" ] || [ "${SVC_TARGETPORT}" = "\"${EXPECTED_PORT}\"" ]; then
    echo "Service targetPort is ${EXPECTED_PORT}"
  else
    echo "Service targetPort is '${SVC_TARGETPORT:-<none>}' (expected ${EXPECTED_PORT})"
    rc=1
  fi

  if [ "${SVC_NODEPORT}" -eq "${EXPECTED_NODEPORT}" ] 2>/dev/null; then
    echo "Service nodePort is ${EXPECTED_NODEPORT}"
  else
    echo "Service nodePort is '${SVC_NODEPORT:-<none>}' (expected ${EXPECTED_NODEPORT})"
    rc=1
  fi

  # Ensure service selects the pod (endpoints)
  echo ""
  echo "4) Checking Service endpoints for ${SVC}..."
  EP_ADDRESSES="$(kubectl get endpoints "${SVC}" -n "${NS}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
  if [ -n "${EP_ADDRESSES}" ]; then
    echo "Endpoints found for Service ${SVC}: ${EP_ADDRESSES}"
    if kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.status.podIP}' >/dev/null 2>&1; then
      POD_IP="$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.status.podIP}' 2>/dev/null || true)"
      if echo "${EP_ADDRESSES}" | tr ' ' '\n' | grep -wq "${POD_IP}"; then
        echo "Service endpoints contain Pod IP ${POD_IP}"
      else
        echo "Service endpoints do not include Pod IP ${POD_IP} (endpoints: ${EP_ADDRESSES})"
        rc=1
      fi
    else
      echo "Unable to determine Pod IP for ${POD}"
      rc=1
    fi
  else
    echo "No endpoints found for Service ${SVC}"
    rc=1
  fi
fi

echo ""
if [ "${rc}" -eq 0 ]; then
  echo "All checks passed"
  exit 0
else
  echo "One or more checks failed"
  exit 1
fi
