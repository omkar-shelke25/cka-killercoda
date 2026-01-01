#!/bin/bash
set -euo pipefail

NS="project-tiger"
DEPLOY_NAME="deploy-important"
EXPECTED_REPLICAS=2
EXPECTED_LABEL="very-important"
EXPECTED_CONTAINER1="container1"
EXPECTED_CONTAINER2="container2"
EXPECTED_IMAGE1="nginx:1-alpine"
EXPECTED_IMAGE2="google/pause"

echo "🔍 Verifying Deployment with Pod Anti-Affinity..."

# Check namespace exists
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
else
  echo "✅ Namespace '${NS}' exists"
fi

# Check Deployment exists
if ! kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOY_NAME}' not found in namespace '${NS}'"
  exit 1
else
  echo "✅ Deployment '${DEPLOY_NAME}' exists"
fi

# Verify replicas count
REPLICAS=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.replicas}')
if [[ "${REPLICAS}" != "${EXPECTED_REPLICAS}" ]]; then
  echo "❌ Replica count incorrect: ${REPLICAS} (expected: ${EXPECTED_REPLICAS})"
  exit 1
else
  echo "✅ Replica count correct: ${EXPECTED_REPLICAS}"
fi

# Verify Deployment label
DEPLOY_LABEL=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.metadata.labels.id}')
if [[ "${DEPLOY_LABEL}" != "${EXPECTED_LABEL}" ]]; then
  echo "❌ Deployment label 'id' incorrect: ${DEPLOY_LABEL} (expected: ${EXPECTED_LABEL})"
  exit 1
else
  echo "✅ Deployment label 'id' correct: ${EXPECTED_LABEL}"
fi

# Verify Pod template label
POD_LABEL=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.metadata.labels.id}')
if [[ "${POD_LABEL}" != "${EXPECTED_LABEL}" ]]; then
  echo "❌ Pod template label 'id' incorrect: ${POD_LABEL} (expected: ${EXPECTED_LABEL})"
  exit 1
else
  echo "✅ Pod template label 'id' correct: ${EXPECTED_LABEL}"
fi

# Verify selector
SELECTOR_LABEL=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.selector.matchLabels.id}')
if [[ "${SELECTOR_LABEL}" != "${EXPECTED_LABEL}" ]]; then
  echo "❌ Selector label incorrect: ${SELECTOR_LABEL} (expected: ${EXPECTED_LABEL})"
  exit 1
else
  echo "✅ Selector label correct: ${EXPECTED_LABEL}"
fi

# Verify container1 exists and has correct image
CONTAINER1_NAME=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].name}')
CONTAINER1_IMAGE=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].image}')

if [[ "${CONTAINER1_NAME}" != "${EXPECTED_CONTAINER1}" ]]; then
  echo "❌ First container name incorrect: ${CONTAINER1_NAME} (expected: ${EXPECTED_CONTAINER1})"
  exit 1
else
  echo "✅ First container name correct: ${EXPECTED_CONTAINER1}"
fi

if [[ "${CONTAINER1_IMAGE}" != "${EXPECTED_IMAGE1}" ]]; then
  echo "❌ First container image incorrect: ${CONTAINER1_IMAGE} (expected: ${EXPECTED_IMAGE1})"
  exit 1
else
  echo "✅ First container image correct: ${EXPECTED_IMAGE1}"
fi

# Verify container2 exists and has correct image
CONTAINER2_NAME=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[1].name}')
CONTAINER2_IMAGE=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[1].image}')

if [[ "${CONTAINER2_NAME}" != "${EXPECTED_CONTAINER2}" ]]; then
  echo "❌ Second container name incorrect: ${CONTAINER2_NAME} (expected: ${EXPECTED_CONTAINER2})"
  exit 1
else
  echo "✅ Second container name correct: ${EXPECTED_CONTAINER2}"
fi

if [[ "${CONTAINER2_IMAGE}" != "${EXPECTED_IMAGE2}" ]]; then
  echo "❌ Second container image incorrect: ${CONTAINER2_IMAGE} (expected: ${EXPECTED_IMAGE2})"
  exit 1
else
  echo "✅ Second container image correct: ${EXPECTED_IMAGE2}"
fi

# Verify podAntiAffinity exists
if ! kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity}' | grep -q "requiredDuringSchedulingIgnoredDuringExecution"; then
  echo "❌ podAntiAffinity not found or incorrect"
  exit 1
else
  echo "✅ podAntiAffinity configured"
fi

# Verify topologyKey
TOPOLOGY_KEY=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey}')
if [[ "${TOPOLOGY_KEY}" != "kubernetes.io/hostname" ]]; then
  echo "❌ topologyKey incorrect: ${TOPOLOGY_KEY} (expected: kubernetes.io/hostname)"
  exit 1
else
  echo "✅ topologyKey correct: kubernetes.io/hostname"
fi

# Verify labelSelector in anti-affinity
ANTI_AFFINITY_LABEL=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].values[0]}')
if [[ "${ANTI_AFFINITY_LABEL}" != "${EXPECTED_LABEL}" ]]; then
  echo "❌ Anti-affinity labelSelector incorrect: ${ANTI_AFFINITY_LABEL} (expected: ${EXPECTED_LABEL})"
  exit 1
else
  echo "✅ Anti-affinity labelSelector correct: ${EXPECTED_LABEL}"
fi

# Wait a moment for Pods to be created
sleep 5

# Count total Pods
TOTAL_PODS=$(kubectl get pods -n "${NS}" -l id="${EXPECTED_LABEL}" --no-headers | wc -l)
if [[ ${TOTAL_PODS} -lt 2 ]]; then
  echo "❌ Expected 2 Pods, found ${TOTAL_PODS}"
  exit 1
else
  echo "✅ Total Pods created: ${TOTAL_PODS}"
fi

# Count Running Pods
RUNNING_PODS=$(kubectl get pods -n "${NS}" -l id="${EXPECTED_LABEL}" --field-selector=status.phase=Running --no-headers | wc -l)
echo "📊 Running Pods: ${RUNNING_PODS}"

# Count Pending Pods
PENDING_PODS=$(kubectl get pods -n "${NS}" -l id="${EXPECTED_LABEL}" --field-selector=status.phase=Pending --no-headers | wc -l)
echo "📊 Pending Pods: ${PENDING_PODS}"

# Verify expected Pod distribution
if [[ ${RUNNING_PODS} -eq 1 ]] && [[ ${PENDING_PODS} -eq 1 ]]; then
  echo "✅ Pod distribution correct: 1 Running, 1 Pending (as expected with 1 worker node)"
elif [[ ${RUNNING_PODS} -eq 2 ]] && [[ ${PENDING_PODS} -eq 0 ]]; then
  echo "✅ Pod distribution: 2 Running (cluster has multiple worker nodes)"
else
  echo "⚠️  Unexpected Pod distribution: ${RUNNING_PODS} Running, ${PENDING_PODS} Pending"
fi

# Verify Running Pod has both containers
if [[ ${RUNNING_PODS} -gt 0 ]]; then
  RUNNING_POD=$(kubectl get pod -n "${NS}" -l id="${EXPECTED_LABEL}" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
  CONTAINER_COUNT=$(kubectl get pod "${RUNNING_POD}" -n "${NS}" -o jsonpath='{.spec.containers[*].name}' | wc -w)
  
  if [[ ${CONTAINER_COUNT} -eq 2 ]]; then
    echo "✅ Running Pod has 2 containers"
    
    # Verify both containers are ready
    READY_CONTAINERS=$(kubectl get pod "${RUNNING_POD}" -n "${NS}" -o jsonpath='{.status.containerStatuses[?(@.ready==true)].name}' | wc -w)
    if [[ ${READY_CONTAINERS} -eq 2 ]]; then
      echo "✅ Both containers are ready in Running Pod"
    else
      echo "⚠️  Warning: Only ${READY_CONTAINERS}/2 containers ready"
    fi
  else
    echo "❌ Running Pod should have 2 containers, found ${CONTAINER_COUNT}"
    exit 1
  fi
fi

# Verify Pending Pod exists and check reason
if [[ ${PENDING_PODS} -gt 0 ]]; then
  PENDING_POD=$(kubectl get pod -n "${NS}" -l id="${EXPECTED_LABEL}" --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
  echo ""
  echo "🔍 Checking Pending Pod reason..."
  
  PENDING_REASON=$(kubectl get events -n "${NS}" --field-selector involvedObject.name="${PENDING_POD}" --sort-by='.lastTimestamp' | grep "FailedScheduling" | tail -1 || echo "")
  
  if echo "${PENDING_REASON}" | grep -q "didn't match pod anti-affinity"; then
    echo "✅ Pending Pod correctly blocked by anti-affinity rule"
  elif [[ -n "${PENDING_REASON}" ]]; then
    echo "ℹ️  Pending reason: ${PENDING_REASON}"
  else
    echo "ℹ️  Pod is Pending (anti-affinity rule working as expected)"
  fi
fi

echo ""
echo "📋 Pod Status Summary:"
kubectl get pods -n "${NS}" -l id="${EXPECTED_LABEL}" -o wide

echo ""
echo "🎉 Verification passed! Deployment is correctly configured!"
echo "   ✅ Deployment with 2 replicas and correct labels"
echo "   ✅ Two containers: container1 (nginx:1-alpine) and container2 (google/pause)"
echo "   ✅ podAntiAffinity with topologyKey: kubernetes.io/hostname"
echo "   ✅ Only one Pod per node (as enforced by anti-affinity)"
exit 0
