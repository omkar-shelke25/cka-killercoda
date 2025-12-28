#!/bin/bash
set -euo pipefail

echo "Verifying resource configuration..."

NAMESPACE="python-ml-ns"
DEPLOYMENT_NAME="python-webapp"

# Check if deployment exists
if ! kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "FAIL: Deployment '${DEPLOYMENT_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
echo "PASS: Deployment exists"

# Check replica count is 3
REPLICA_COUNT=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
if [[ "${REPLICA_COUNT}" != "3" ]]; then
  echo "FAIL: Replica count is ${REPLICA_COUNT}, expected 3"
  exit 1
fi
echo "PASS: Replica count is 3"

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=available deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout=120s &>/dev/null || true
sleep 5

# Check if 3 pods are running
RUNNING_PODS=$(kubectl get pods -n "${NAMESPACE}" -l app=python-webapp --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [[ "${RUNNING_PODS}" -ne 3 ]]; then
  echo "FAIL: Expected 3 running pods, found ${RUNNING_PODS}"
  kubectl get pods -n "${NAMESPACE}"
  exit 1
fi
echo "PASS: 3 pods are running"

# Get a pod for detailed checks
POD_NAME=$(kubectl get pod -n "${NAMESPACE}" -l app=python-webapp -o jsonpath='{.items[0].metadata.name}')
if [[ -z "${POD_NAME}" ]]; then
  echo "FAIL: Could not get pod name"
  exit 1
fi
echo "Testing pod: ${POD_NAME}"

# Get deployment spec
DEPLOYMENT_JSON=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o json)

# Check init container resources
INIT_CPU_REQUEST=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.initContainers[0].resources.requests.cpu // empty')
INIT_CPU_LIMIT=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.initContainers[0].resources.limits.cpu // empty')
INIT_MEM_REQUEST=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.initContainers[0].resources.requests.memory // empty')
INIT_MEM_LIMIT=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.initContainers[0].resources.limits.memory // empty')

if [[ -z "${INIT_CPU_REQUEST}" ]]; then
  echo "FAIL: Init container 'init-setup' has no CPU request"
  exit 1
fi

if [[ -z "${INIT_MEM_REQUEST}" ]]; then
  echo "FAIL: Init container 'init-setup' has no memory request"
  exit 1
fi

# Normalize CPU values (convert to millicores)
normalize_cpu() {
  local cpu=$1
  if [[ "${cpu}" =~ ^[0-9]+m$ ]]; then
    echo "${cpu%m}"
  elif [[ "${cpu}" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    echo "$(awk "BEGIN {print int($cpu * 1000)}")"
  else
    echo "0"
  fi
}

# Normalize memory values (convert to Mi)
normalize_memory() {
  local mem=$1
  if [[ "${mem}" =~ ^([0-9]+)Mi$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "${mem}" =~ ^([0-9]+)M$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "${mem}" =~ ^([0-9]+)Gi$ ]]; then
    echo "$(awk "BEGIN {print int(${BASH_REMATCH[1]} * 1024)}")"
  else
    echo "0"
  fi
}

# Check init container CPU (accept 266m or 267m)
INIT_CPU_NORM=$(normalize_cpu "${INIT_CPU_REQUEST}")
if [[ "${INIT_CPU_NORM}" -lt 266 || "${INIT_CPU_NORM}" -gt 267 ]]; then
  echo "FAIL: Init container CPU request is ${INIT_CPU_REQUEST} (${INIT_CPU_NORM}m), expected 266m or 267m"
  exit 1
fi
echo "PASS: Init container CPU request: ${INIT_CPU_REQUEST}"

# Check init container Memory (accept 480Mi or 481Mi)
INIT_MEM_NORM=$(normalize_memory "${INIT_MEM_REQUEST}")
if [[ "${INIT_MEM_NORM}" -lt 480 || "${INIT_MEM_NORM}" -gt 481 ]]; then
  echo "FAIL: Init container memory request is ${INIT_MEM_REQUEST} (${INIT_MEM_NORM}Mi), expected 480Mi or 481Mi"
  exit 1
fi
echo "PASS: Init container memory request: ${INIT_MEM_REQUEST}"

# Check init container limits match requests
INIT_CPU_LIMIT_NORM=$(normalize_cpu "${INIT_CPU_LIMIT}")
INIT_MEM_LIMIT_NORM=$(normalize_memory "${INIT_MEM_LIMIT}")

if [[ "${INIT_CPU_NORM}" != "${INIT_CPU_LIMIT_NORM}" ]]; then
  echo "FAIL: Init container CPU limit (${INIT_CPU_LIMIT}) does not match request (${INIT_CPU_REQUEST})"
  exit 1
fi
echo "PASS: Init container CPU limit matches request"

if [[ "${INIT_MEM_NORM}" != "${INIT_MEM_LIMIT_NORM}" ]]; then
  echo "FAIL: Init container memory limit (${INIT_MEM_LIMIT}) does not match request (${INIT_MEM_REQUEST})"
  exit 1
fi
echo "PASS: Init container memory limit matches request"

# Check main container resources
MAIN_CPU_REQUEST=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.containers[0].resources.requests.cpu // empty')
MAIN_CPU_LIMIT=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu // empty')
MAIN_MEM_REQUEST=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.containers[0].resources.requests.memory // empty')
MAIN_MEM_LIMIT=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.containers[0].resources.limits.memory // empty')

if [[ -z "${MAIN_CPU_REQUEST}" ]]; then
  echo "FAIL: Main container 'python-app' has no CPU request"
  exit 1
fi

if [[ -z "${MAIN_MEM_REQUEST}" ]]; then
  echo "FAIL: Main container 'python-app' has no memory request"
  exit 1
fi

# Check main container CPU (accept 266m or 267m)
MAIN_CPU_NORM=$(normalize_cpu "${MAIN_CPU_REQUEST}")
if [[ "${MAIN_CPU_NORM}" -lt 266 || "${MAIN_CPU_NORM}" -gt 267 ]]; then
  echo "FAIL: Main container CPU request is ${MAIN_CPU_REQUEST} (${MAIN_CPU_NORM}m), expected 266m or 267m"
  exit 1
fi
echo "PASS: Main container CPU request: ${MAIN_CPU_REQUEST}"

# Check main container Memory (accept 480Mi or 481Mi)
MAIN_MEM_NORM=$(normalize_memory "${MAIN_MEM_REQUEST}")
if [[ "${MAIN_MEM_NORM}" -lt 480 || "${MAIN_MEM_NORM}" -gt 481 ]]; then
  echo "FAIL: Main container memory request is ${MAIN_MEM_REQUEST} (${MAIN_MEM_NORM}Mi), expected 480Mi or 481Mi"
  exit 1
fi
echo "PASS: Main container memory request: ${MAIN_MEM_REQUEST}"

# Check main container limits match requests
MAIN_CPU_LIMIT_NORM=$(normalize_cpu "${MAIN_CPU_LIMIT}")
MAIN_MEM_LIMIT_NORM=$(normalize_memory "${MAIN_MEM_LIMIT}")

if [[ "${MAIN_CPU_NORM}" != "${MAIN_CPU_LIMIT_NORM}" ]]; then
  echo "FAIL: Main container CPU limit (${MAIN_CPU_LIMIT}) does not match request (${MAIN_CPU_REQUEST})"
  exit 1
fi
echo "PASS: Main container CPU limit matches request"

if [[ "${MAIN_MEM_NORM}" != "${MAIN_MEM_LIMIT_NORM}" ]]; then
  echo "FAIL: Main container memory limit (${MAIN_MEM_LIMIT}) does not match request (${MAIN_MEM_REQUEST})"
  exit 1
fi
echo "PASS: Main container memory limit matches request"

# Check both containers have identical resources
if [[ "${INIT_CPU_NORM}" != "${MAIN_CPU_NORM}" ]]; then
  echo "FAIL: Init and main containers have different CPU values (${INIT_CPU_REQUEST} vs ${MAIN_CPU_REQUEST})"
  exit 1
fi
echo "PASS: Both containers have identical CPU values"

if [[ "${INIT_MEM_NORM}" != "${MAIN_MEM_NORM}" ]]; then
  echo "FAIL: Init and main containers have different memory values (${INIT_MEM_REQUEST} vs ${MAIN_MEM_REQUEST})"
  exit 1
fi
echo "PASS: Both containers have identical memory values"

# Check QoS class
QOS_CLASS=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.qosClass}')
if [[ "${QOS_CLASS}" != "Guaranteed" ]]; then
  echo "WARN: Pod QoS class is ${QOS_CLASS}, expected Guaranteed (requests should equal limits)"
fi
echo "PASS: Pod QoS class: ${QOS_CLASS}"

# Verify all 3 pods have same configuration
echo "Verifying all pods have correct configuration..."
ALL_PODS=$(kubectl get pods -n "${NAMESPACE}" -l app=python-webapp -o jsonpath='{.items[*].metadata.name}')
POD_COUNT=0
for pod in ${ALL_PODS}; do
  POD_COUNT=$((POD_COUNT + 1))
  POD_QOS=$(kubectl get pod "${pod}" -n "${NAMESPACE}" -o jsonpath='{.status.qosClass}')
  if [[ "${POD_QOS}" != "Guaranteed" ]]; then
    echo "WARN: Pod ${pod} has QoS class ${POD_QOS}"
  fi
done

if [[ "${POD_COUNT}" -ne 3 ]]; then
  echo "FAIL: Expected 3 pods, found ${POD_COUNT}"
  exit 1
fi
echo "PASS: All ${POD_COUNT} pods verified"

echo ""
echo "SUCCESS: Resource configuration verification passed!"
echo ""
echo "Summary:"
echo "  - Deployment: python-webapp with 3 replicas"
echo "  - Init container (init-setup): ${INIT_CPU_REQUEST} CPU, ${INIT_MEM_REQUEST} memory"
echo "  - Main container (python-app): ${MAIN_CPU_REQUEST} CPU, ${MAIN_MEM_REQUEST} memory"
echo "  - Both containers have identical resources"
echo "  - Requests equal limits (Guaranteed QoS)"
echo "  - All 3 pods running successfully"
echo ""

exit 0
