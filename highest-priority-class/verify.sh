#!/bin/bash
set -euo pipefail

NAMESPACE="priority"
DEPLOYMENT_NAME="acme-log-forwarder"
PRIORITYCLASS_NAME="high-priority"
EXPECTED_VALUE=999999

echo "🔍 Verifying PriorityClass Configuration for Holiday Flash Sale..."
echo ""

ERRORS=0

# Task 1: Verify PriorityClass exists
echo "📊 Task 1: Checking PriorityClass 'high-priority'..."

if ! kubectl get priorityclass "${PRIORITYCLASS_NAME}" &>/dev/null; then
  echo "❌ PriorityClass '${PRIORITYCLASS_NAME}' not found"
  echo "💡 Hint: Create it with: kubectl apply -f <priorityclass.yaml>"
  ((ERRORS++))
  exit 1
else
  echo "✅ PriorityClass '${PRIORITYCLASS_NAME}' exists"
fi

# Get PriorityClass details
PC_JSON=$(kubectl get priorityclass "${PRIORITYCLASS_NAME}" -o json)

# Verify value
PC_VALUE=$(echo "${PC_JSON}" | jq -r '.value')
if [[ "${PC_VALUE}" != "${EXPECTED_VALUE}" ]]; then
  echo "❌ PriorityClass value is '${PC_VALUE}', expected '${EXPECTED_VALUE}'"
  echo "💡 Hint: The value should be one less than the highest user-defined PriorityClass"
  echo "   Highest user-defined: payment-critical (1000000)"
  echo "   Your value should be: 999999"
  ((ERRORS++))
else
  echo "✅ PriorityClass value: ${EXPECTED_VALUE}"
fi

# Verify globalDefault
PC_GLOBAL=$(echo "${PC_JSON}" | jq -r '.globalDefault // "notset"')
if [[ "${PC_GLOBAL}" != "false" ]]; then
  echo "❌ PriorityClass globalDefault is '${PC_GLOBAL}', expected 'false'"
  echo "💡 Hint: Set globalDefault: false in your PriorityClass"
  ((ERRORS++))
else
  echo "✅ PriorityClass globalDefault: false"
fi

# Verify preemptionPolicy
PC_PREEMPTION=$(echo "${PC_JSON}" | jq -r '.preemptionPolicy // "notset"')
if [[ "${PC_PREEMPTION}" != "PreemptLowerPriority" ]]; then
  echo "❌ PriorityClass preemptionPolicy is '${PC_PREEMPTION}', expected 'PreemptLowerPriority'"
  echo "💡 Hint: Set preemptionPolicy: PreemptLowerPriority in your PriorityClass"
  ((ERRORS++))
else
  echo "✅ PriorityClass preemptionPolicy: PreemptLowerPriority"
fi

# Task 2: Verify Deployment uses PriorityClass
echo ""
echo "🔧 Task 2: Checking Deployment '${DEPLOYMENT_NAME}'..."

if ! kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT_NAME}' not found in namespace '${NAMESPACE}'"
  ((ERRORS++))
  exit 1
fi

# Get Deployment details
DEPLOYMENT_JSON=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o json)

# Check if priorityClassName is set in pod template
DEPLOY_PC=$(echo "${DEPLOYMENT_JSON}" | jq -r '.spec.template.spec.priorityClassName // "notset"')
if [[ "${DEPLOY_PC}" != "${PRIORITYCLASS_NAME}" ]]; then
  echo "❌ Deployment priorityClassName is '${DEPLOY_PC}', expected '${PRIORITYCLASS_NAME}'"
  echo "💡 Hint: Update the deployment with:"
  echo "   kubectl edit deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}"
  echo "   Add under spec.template.spec:"
  echo "     priorityClassName: ${PRIORITYCLASS_NAME}"
  ((ERRORS++))
else
  echo "✅ Deployment uses priorityClassName: ${PRIORITYCLASS_NAME}"
fi

# Verify pods are using the PriorityClass
echo ""
echo "🔍 Task 3: Verifying Pods are using PriorityClass..."

POD_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l app=log-forwarder --no-headers 2>/dev/null | wc -l)
if [[ ${POD_COUNT} -eq 0 ]]; then
  echo "⚠️  No pods found for deployment"
  echo "   Pods may still be starting..."
else
  echo "   Found ${POD_COUNT} pod(s)"
  
  # Check each pod
  PODS_WITH_PRIORITY=0
  while IFS= read -r POD_NAME; do
    POD_PC=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.priorityClassName}' 2>/dev/null || echo "")
    POD_PRIORITY=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.priority}' 2>/dev/null || echo "0")
    
    if [[ "${POD_PC}" == "${PRIORITYCLASS_NAME}" ]]; then
      ((PODS_WITH_PRIORITY++))
    fi
    
    if [[ "${POD_PRIORITY}" == "${EXPECTED_VALUE}" ]]; then
      echo "   ✅ Pod ${POD_NAME}: priority=${POD_PRIORITY}"
    else
      echo "   ⚠️  Pod ${POD_NAME}: priority=${POD_PRIORITY} (expected ${EXPECTED_VALUE})"
    fi
  done < <(kubectl get pods -n "${NAMESPACE}" -l app=log-forwarder -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
  
  if [[ ${PODS_WITH_PRIORITY} -eq ${POD_COUNT} ]]; then
    echo "✅ All pods are using priorityClassName: ${PRIORITYCLASS_NAME}"
  else
    echo "⚠️  Only ${PODS_WITH_PRIORITY}/${POD_COUNT} pods have correct PriorityClass"
    echo "   This may be normal if pods are still rolling out"
  fi
fi

# Verify no system PriorityClasses were used
echo ""
echo "🔒 Security Check: Verifying system PriorityClasses were not used..."

if [[ "${PC_VALUE}" -ge 1000000000 ]]; then
  echo "❌ ERROR: PriorityClass value is in system range (>= 1 billion)"
  echo "   System PriorityClasses are reserved for Kubernetes components"
  echo "   User-defined classes should be below 1,000,000,000"
  ((ERRORS++))
else
  echo "✅ PriorityClass value is in valid user-defined range"
fi

# Show priority hierarchy
echo ""
echo "📊 Priority Hierarchy After Configuration:"
echo ""
kubectl get priorityclasses --sort-by=.value 2>/dev/null | grep -E "NAME|payment-critical|high-priority|inventory-high|frontend-medium|analytics-low" || true

# Final summary
echo ""
echo "═══════════════════════════════════════════════════════════"

if [[ ${ERRORS} -eq 0 ]]; then
  echo ""
  echo "🎉 SUCCESS - Configuration Complete!"
  echo ""
  echo "✅ All verification checks passed!"
  echo ""
  echo "📊 Configuration Summary:"
  echo "   • PriorityClass: ${PRIORITYCLASS_NAME}"
  echo "   • Value: ${EXPECTED_VALUE}"
  echo "   • globalDefault: false"
  echo "   • preemptionPolicy: PreemptLowerPriority"
  echo "   • Deployment: ${DEPLOYMENT_NAME} (${NAMESPACE})"
  echo "   • Pods: Using priority ${EXPECTED_VALUE}"
  echo ""
  echo "🛒 Holiday Flash Sale Readiness:"
  echo "   ✅ Payment services: Priority 1,000,000"
  echo "   ✅ Log forwarder: Priority 999,999 ← Your configuration"
  echo "   ✅ Inventory: Priority 800,000"
  echo "   ✅ Frontend: Priority 500,000"
  echo "   ✅ Analytics: Priority 100,000"
  echo ""
  echo "🎁 The log forwarder will now maintain high priority during"
  echo "   the Holiday Flash Sale, ensuring transaction logs are"
  echo "   preserved for compliance and fraud detection!"
  echo ""
  echo "💡 During resource pressure:"
  echo "   • Payment services scheduled first"
  echo "   • Log forwarder scheduled second ← Protected!"
  echo "   • Lower priority services may be evicted"
  echo ""
  echo "🏆 AcmeRetail Operations Team: 'Excellent work!'"
  echo "   Your configuration ensures log continuity during peak traffic."
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  exit 0
else
  echo ""
  echo "❌ CONFIGURATION INCOMPLETE"
  echo ""
  echo "Found ${ERRORS} error(s) in configuration"
  echo ""
  echo "⚠️  The Holiday Flash Sale is approaching!"
  echo "   Without proper PriorityClass configuration:"
  echo "   • Log forwarder may be evicted during peak load"
  echo "   • Transaction logs could be lost"
  echo "   • Compliance violations possible"
  echo "   • Fraud detection compromised"
  echo ""
  echo "💡 Review the errors above and fix the configuration."
  echo ""
  echo "📚 Quick fixes:"
  echo "   • Ensure PriorityClass value is 999999"
  echo "   • Set globalDefault: false"
  echo "   • Set preemptionPolicy: PreemptLowerPriority"
  echo "   • Update deployment: kubectl edit deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}"
  echo "   • Add: priorityClassName: ${PRIORITYCLASS_NAME}"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi
