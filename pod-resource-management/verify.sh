#!/bin/bash
set -euo pipefail

NAMESPACE="python-ml-ns"
DEPLOYMENT="python-webapp"
EXPECTED_REPLICAS=3
EXPECTED_CPU="266m"
EXPECTED_MEMORY="480Mi"

# Node allocatable resources (from setup)
NODE_TOTAL_CPU=1000  # in millicores
NODE_TOTAL_MEMORY=1803  # in Mi
OVERHEAD_PERCENT=20

echo "🔍 Verifying Python ML Web Application Resource Configuration..."
echo ""

# Calculate expected values
OVERHEAD_CPU=$((NODE_TOTAL_CPU * OVERHEAD_PERCENT / 100))
OVERHEAD_MEM=$((NODE_TOTAL_MEMORY * OVERHEAD_PERCENT / 100))
AVAILABLE_CPU=$((NODE_TOTAL_CPU - OVERHEAD_CPU))
AVAILABLE_MEM=$((NODE_TOTAL_MEMORY - OVERHEAD_MEM))
PER_POD_CPU=$((AVAILABLE_CPU / EXPECTED_REPLICAS))
PER_POD_MEM=$((AVAILABLE_MEM / EXPECTED_REPLICAS))

echo "📊 Resource Calculation Verification:"
echo "   Node Total: ${NODE_TOTAL_CPU}m CPU, ${NODE_TOTAL_MEMORY}Mi Memory"
echo "   Overhead (20%): ${OVERHEAD_CPU}m CPU, ${OVERHEAD_MEM}Mi Memory"
echo "   Available: ${AVAILABLE_CPU}m CPU, ${AVAILABLE_MEM}Mi Memory"
echo "   Expected per Pod: ${PER_POD_CPU}m CPU, ${PER_POD_MEM}Mi Memory"
echo ""

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  echo "❌ Namespace '${NAMESPACE}' not found"
  exit 1
fi
echo "✅ Namespace '${NAMESPACE}' exists"

# Check if deployment exists
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
echo "✅ Deployment '${DEPLOYMENT}' exists"

# Check replica count
CURRENT_REPLICAS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
if [[ "${CURRENT_REPLICAS}" != "${EXPECTED_REPLICAS}" ]]; then
  echo "❌ Deployment has ${CURRENT_REPLICAS} replicas, expected ${EXPECTED_REPLICAS}"
  echo "💡 Hint: Run: kubectl scale deployment ${DEPLOYMENT} --replicas=${EXPECTED_REPLICAS} -n ${NAMESPACE}"
  exit 1
fi
echo "✅ Deployment scaled to ${EXPECTED_REPLICAS} replicas"

# Wait for pods to be ready
echo ""
echo "⏳ Waiting for pods to be ready..."
if ! kubectl wait --for=condition=ready pod -l app="${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=120s &>/dev/null; then
  echo "❌ Pods are not ready within timeout"
  echo ""
  echo "Current pod status:"
  kubectl get pods -l app="${DEPLOYMENT}" -n "${NAMESPACE}"
  echo ""
  echo "💡 Check pod events: kubectl describe pod -l app=${DEPLOYMENT} -n ${NAMESPACE}"
  exit 1
fi

# Check if all pods are running
RUNNING_PODS=$(kubectl get pods -l app="${DEPLOYMENT}" -n "${NAMESPACE}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [[ "${RUNNING_PODS}" != "${EXPECTED_REPLICAS}" ]]; then
  echo "❌ Only ${RUNNING_PODS}/${EXPECTED_REPLICAS} pods are running"
  echo ""
  kubectl get pods -l app="${DEPLOYMENT}" -n "${NAMESPACE}"
  exit 1
fi
echo "✅ All ${EXPECTED_REPLICAS} pods are in Running state"

# Get one pod for detailed checks
POD_NAME=$(kubectl get pods -l app="${DEPLOYMENT}" -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}')

# Check init container resources
echo ""
echo "🔍 Verifying init container resources..."

INIT_CPU_REQUEST=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.initContainers[0].resources.requests.cpu}')
INIT_CPU_LIMIT=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.initContainers[0].resources.limits.cpu}')
INIT_MEM_REQUEST=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.initContainers[0].resources.requests.memory}')
INIT_MEM_LIMIT=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.initContainers[0].resources.limits.memory}')

# Normalize CPU values (remove 'm' suffix if present, add it back)
INIT_CPU_REQUEST=$(echo "${INIT_CPU_REQUEST}" | sed 's/m$//')
INIT_CPU_LIMIT=$(echo "${INIT_CPU_LIMIT}" | sed 's/m$//')
EXPECTED_CPU_NUM=$(echo "${EXPECTED_CPU}" | sed 's/m$//')

# Normalize memory values
INIT_MEM_REQUEST=$(echo "${INIT_MEM_REQUEST}" | sed 's/Mi$//')
INIT_MEM_LIMIT=$(echo "${INIT_MEM_LIMIT}" | sed 's/Mi$//')
EXPECTED_MEMORY_NUM=$(echo "${EXPECTED_MEMORY}" | sed 's/Mi$//')

if [[ -z "${INIT_CPU_REQUEST}" ]]; then
  echo "❌ Init container has no CPU request configured"
  echo "💡 Hint: Add resources.requests.cpu to the init container (init-setup)"
  exit 1
fi

if [[ -z "${INIT_MEM_REQUEST}" ]]; then
  echo "❌ Init container has no memory request configured"
  echo "💡 Hint: Add resources.requests.memory to the init container (init-setup)"
  exit 1
fi

# Check if init container values are correct (allow small variance)
if [[ "${INIT_CPU_REQUEST}" != "${EXPECTED_CPU_NUM}" ]]; then
  echo "❌ Init container CPU request is ${INIT_CPU_REQUEST}m, expected ${EXPECTED_CPU}"
  echo "💡 Calculation: (1000m - 200m) ÷ 3 = 266m per pod"
  exit 1
fi

if [[ "${INIT_CPU_LIMIT}" != "${EXPECTED_CPU_NUM}" ]]; then
  echo "❌ Init container CPU limit is ${INIT_CPU_LIMIT}m, expected ${EXPECTED_CPU}"
  exit 1
fi

if [[ "${INIT_MEM_REQUEST}" != "${EXPECTED_MEMORY_NUM}" ]]; then
  echo "❌ Init container memory request is ${INIT_MEM_REQUEST}Mi, expected ${EXPECTED_MEMORY}"
  echo "💡 Calculation: (1803Mi - 361Mi) ÷ 3 = 480Mi per pod"
  exit 1
fi

if [[ "${INIT_MEM_LIMIT}" != "${EXPECTED_MEMORY_NUM}" ]]; then
  echo "❌ Init container memory limit is ${INIT_MEM_LIMIT}Mi, expected ${EXPECTED_MEMORY}"
  exit 1
fi

echo "✅ Init container (init-setup) resources configured correctly:"
echo "   CPU: ${INIT_CPU_REQUEST}m (request) = ${INIT_CPU_LIMIT}m (limit)"
echo "   Memory: ${INIT_MEM_REQUEST}Mi (request) = ${INIT_MEM_LIMIT}Mi (limit)"

# Check main container resources
echo ""
echo "🔍 Verifying main container resources..."

MAIN_CPU_REQUEST=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
MAIN_CPU_LIMIT=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
MAIN_MEM_REQUEST=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.containers[0].resources.requests.memory}')
MAIN_MEM_LIMIT=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.containers[0].resources.limits.memory}')

# Normalize values
MAIN_CPU_REQUEST=$(echo "${MAIN_CPU_REQUEST}" | sed 's/m$//')
MAIN_CPU_LIMIT=$(echo "${MAIN_CPU_LIMIT}" | sed 's/m$//')
MAIN_MEM_REQUEST=$(echo "${MAIN_MEM_REQUEST}" | sed 's/Mi$//')
MAIN_MEM_LIMIT=$(echo "${MAIN_MEM_LIMIT}" | sed 's/Mi$//')

if [[ -z "${MAIN_CPU_REQUEST}" ]]; then
  echo "❌ Main container has no CPU request configured"
  echo "💡 Hint: Add resources.requests.cpu to the main container (python-app)"
  exit 1
fi

if [[ -z "${MAIN_MEM_REQUEST}" ]]; then
  echo "❌ Main container has no memory request configured"
  echo "💡 Hint: Add resources.requests.memory to the main container (python-app)"
  exit 1
fi

if [[ "${MAIN_CPU_REQUEST}" != "${EXPECTED_CPU_NUM}" ]]; then
  echo "❌ Main container CPU request is ${MAIN_CPU_REQUEST}m, expected ${EXPECTED_CPU}"
  exit 1
fi

if [[ "${MAIN_CPU_LIMIT}" != "${EXPECTED_CPU_NUM}" ]]; then
  echo "❌ Main container CPU limit is ${MAIN_CPU_LIMIT}m, expected ${EXPECTED_CPU}"
  exit 1
fi

if [[ "${MAIN_MEM_REQUEST}" != "${EXPECTED_MEMORY_NUM}" ]]; then
  echo "❌ Main container memory request is ${MAIN_MEM_REQUEST}Mi, expected ${EXPECTED_MEMORY}"
  exit 1
fi

if [[ "${MAIN_MEM_LIMIT}" != "${EXPECTED_MEMORY_NUM}" ]]; then
  echo "❌ Main container memory limit is ${MAIN_MEM_LIMIT}Mi, expected ${EXPECTED_MEMORY}"
  exit 1
fi

echo "✅ Main container (python-app) resources configured correctly:"
echo "   CPU: ${MAIN_CPU_REQUEST}m (request) = ${MAIN_CPU_LIMIT}m (limit)"
echo "   Memory: ${MAIN_MEM_REQUEST}Mi (request) = ${MAIN_MEM_LIMIT}Mi (limit)"

# Verify init and main containers have identical resources
echo ""
echo "🔍 Verifying init and main containers have identical resources..."

if [[ "${INIT_CPU_REQUEST}" != "${MAIN_CPU_REQUEST}" ]] || \
   [[ "${INIT_CPU_LIMIT}" != "${MAIN_CPU_LIMIT}" ]] || \
   [[ "${INIT_MEM_REQUEST}" != "${MAIN_MEM_REQUEST}" ]] || \
   [[ "${INIT_MEM_LIMIT}" != "${MAIN_MEM_LIMIT}" ]]; then
  echo "❌ Init and main containers have different resources"
  echo "   Init: ${INIT_CPU_REQUEST}m CPU, ${INIT_MEM_REQUEST}Mi Memory"
  echo "   Main: ${MAIN_CPU_REQUEST}m CPU, ${MAIN_MEM_REQUEST}Mi Memory"
  echo "💡 Both containers must have identical resource values"
  exit 1
fi

echo "✅ Init and main containers have identical resources"

# Verify requests equal limits (Guaranteed QoS)
echo ""
echo "🔍 Verifying requests equal limits (Guaranteed QoS)..."

if [[ "${INIT_CPU_REQUEST}" != "${INIT_CPU_LIMIT}" ]] || \
   [[ "${INIT_MEM_REQUEST}" != "${INIT_MEM_LIMIT}" ]] || \
   [[ "${MAIN_CPU_REQUEST}" != "${MAIN_CPU_LIMIT}" ]] || \
   [[ "${MAIN_MEM_REQUEST}" != "${MAIN_MEM_LIMIT}" ]]; then
  echo "❌ Requests and limits are not equal"
  echo "💡 For Guaranteed QoS, requests must equal limits"
  exit 1
fi

echo "✅ Requests equal limits (Guaranteed QoS)"

# Verify QoS class
QOS_CLASS=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.qosClass}')
if [[ "${QOS_CLASS}" != "Guaranteed" ]]; then
  echo "⚠️  Warning: QoS class is '${QOS_CLASS}', expected 'Guaranteed'"
  echo "   This should be 'Guaranteed' when requests equal limits"
else
  echo "✅ QoS Class: Guaranteed"
fi

# Check total resource allocation
echo ""
echo "🔍 Checking total resource allocation..."

TOTAL_CPU_USED=$((EXPECTED_CPU_NUM * EXPECTED_REPLICAS))
TOTAL_MEM_USED=$((EXPECTED_MEMORY_NUM * EXPECTED_REPLICAS))

echo "   Total allocated: ${TOTAL_CPU_USED}m CPU, ${TOTAL_MEM_USED}Mi Memory"
echo "   Available capacity: ${AVAILABLE_CPU}m CPU, ${AVAILABLE_MEM}Mi Memory"

if [[ "${TOTAL_CPU_USED}" -gt "${AVAILABLE_CPU}" ]]; then
  echo "❌ Total CPU allocation (${TOTAL_CPU_USED}m) exceeds available capacity (${AVAILABLE_CPU}m)"
  exit 1
fi

if [[ "${TOTAL_MEM_USED}" -gt "${AVAILABLE_MEM}" ]]; then
  echo "❌ Total memory allocation (${TOTAL_MEM_USED}Mi) exceeds available capacity (${AVAILABLE_MEM}Mi)"
  exit 1
fi

echo "✅ Total resource allocation within node capacity"

# Test application connectivity
echo ""
echo "🔍 Testing application connectivity..."

if kubectl run test-curl-verify --image=curlimages/curl -i --rm --restart=Never --timeout=30s -n "${NAMESPACE}" -- \
  curl -s -f http://python-webapp.${NAMESPACE}.svc.cluster.local > /dev/null 2>&1; then
  echo "✅ Application is responding to HTTP requests"
else
  echo "⚠️  Warning: Could not verify HTTP connectivity (non-critical)"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Verification Complete! All checks passed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Configuration Summary:"
echo "   ✅ Namespace: ${NAMESPACE}"
echo "   ✅ Deployment: ${DEPLOYMENT}"
echo "   ✅ Replicas: ${EXPECTED_REPLICAS}/${EXPECTED_REPLICAS} running"
echo "   ✅ CPU per Pod: ${EXPECTED_CPU}"
echo "   ✅ Memory per Pod: ${EXPECTED_MEMORY}"
echo "   ✅ Init container (init-setup) configured correctly"
echo "   ✅ Main container (python-app) configured correctly"
echo "   ✅ Resources identical in both containers"
echo "   ✅ Requests equal limits (Guaranteed QoS)"
echo "   ✅ QoS Class: ${QOS_CLASS}"
echo "   ✅ Total allocation within node capacity"
echo ""
echo "🎯 Resource Calculation Verified:"
echo "   Formula: (Total - 20% Overhead) ÷ 3 Pods"
echo "   CPU: (1000m - 200m) ÷ 3 = 266m per pod ✅"
echo "   Memory: (1803Mi - 361Mi) ÷ 3 = 480Mi per pod ✅"
echo ""
exit 0
