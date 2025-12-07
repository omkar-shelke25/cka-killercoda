#!/bin/bash

NAMESPACE="priority"
DEPLOYMENT_NAME="acme-log-forwarder"
PRIORITYCLASS_NAME="high-priority"
EXPECTED_VALUE=999999

echo "🔍 Verifying PriorityClass Configuration for Holiday Flash Sale..."
echo ""

ERRORS=0

# Check if PriorityClass exists
echo "📊 Checking PriorityClass 'high-priority'..."
if ! kubectl get priorityclass ${PRIORITYCLASS_NAME} >/dev/null 2>&1; then
  echo "❌ PriorityClass '${PRIORITYCLASS_NAME}' not found"
  echo "💡 Hint: Create it with: kubectl apply -f <priorityclass.yaml>"
  exit 1
fi
echo "✅ PriorityClass '${PRIORITYCLASS_NAME}' exists"

# Check value
PC_VALUE=$(kubectl get priorityclass ${PRIORITYCLASS_NAME} -o jsonpath='{.value}')
if [ "$PC_VALUE" != "$EXPECTED_VALUE" ]; then
  echo "❌ PriorityClass value is '${PC_VALUE}', expected '${EXPECTED_VALUE}'"
  echo "💡 Hint: The value should be one less than the highest user-defined PriorityClass"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PriorityClass value: ${EXPECTED_VALUE}"
fi

# Check globalDefault (should be false or not set)
PC_GLOBAL=$(kubectl get priorityclass ${PRIORITYCLASS_NAME} -o jsonpath='{.globalDefault}')
if [ "$PC_GLOBAL" = "true" ]; then
  echo "❌ PriorityClass globalDefault is 'true', expected 'false'"
  echo "💡 Hint: Set globalDefault: false in your PriorityClass"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PriorityClass globalDefault: false"
fi

# Check preemptionPolicy (should be PreemptLowerPriority or not set)
PC_PREEMPTION=$(kubectl get priorityclass ${PRIORITYCLASS_NAME} -o jsonpath='{.preemptionPolicy}')
if [ -z "$PC_PREEMPTION" ]; then
  echo "✅ PriorityClass preemptionPolicy: PreemptLowerPriority (default)"
elif [ "$PC_PREEMPTION" = "PreemptLowerPriority" ]; then
  echo "✅ PriorityClass preemptionPolicy: PreemptLowerPriority"
else
  echo "❌ PriorityClass preemptionPolicy is '${PC_PREEMPTION}', expected 'PreemptLowerPriority'"
  echo "💡 Hint: Set preemptionPolicy: PreemptLowerPriority in your PriorityClass"
  ERRORS=$((ERRORS + 1))
fi

# Check Deployment
echo ""
echo "🔧 Checking Deployment '${DEPLOYMENT_NAME}'..."

if ! kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "❌ Deployment '${DEPLOYMENT_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi

# Check if priorityClassName is set
DEPLOY_PC=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.priorityClassName}')
if [ -z "$DEPLOY_PC" ]; then
  echo "❌ Deployment does not have priorityClassName set"
  echo "💡 Hint: Update the deployment with:"
  echo "   kubectl edit deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}"
  echo "   Add under spec.template.spec:"
  echo "     priorityClassName: ${PRIORITYCLASS_NAME}"
  ERRORS=$((ERRORS + 1))
elif [ "$DEPLOY_PC" != "$PRIORITYCLASS_NAME" ]; then
  echo "❌ Deployment priorityClassName is '${DEPLOY_PC}', expected '${PRIORITYCLASS_NAME}'"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ Deployment uses priorityClassName: ${PRIORITYCLASS_NAME}"
fi

# Check pods
echo ""
echo "🔍 Verifying Pods..."

POD_COUNT=$(kubectl get pods -n ${NAMESPACE} -l app=log-forwarder --no-headers 2>/dev/null | wc -l)
if [ "$POD_COUNT" -eq 0 ]; then
  echo "⚠️  No pods found - they may still be starting"
else
  echo "   Found ${POD_COUNT} pod(s)"
  
  # Check first pod
  FIRST_POD=$(kubectl get pods -n ${NAMESPACE} -l app=log-forwarder -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$FIRST_POD" ]; then
    POD_PC=$(kubectl get pod ${FIRST_POD} -n ${NAMESPACE} -o jsonpath='{.spec.priorityClassName}')
    POD_PRIORITY=$(kubectl get pod ${FIRST_POD} -n ${NAMESPACE} -o jsonpath='{.spec.priority}')
    
    if [ "$POD_PC" = "$PRIORITYCLASS_NAME" ]; then
      echo "✅ Pods are using priorityClassName: ${PRIORITYCLASS_NAME}"
    fi
    
    if [ "$POD_PRIORITY" = "$EXPECTED_VALUE" ]; then
      echo "✅ Pods have priority value: ${POD_PRIORITY}"
    fi
  fi
fi

# Check priority value is in valid range
echo ""
echo "🔒 Security Check..."
if [ "$PC_VALUE" -ge 1000000000 ]; then
  echo "❌ ERROR: PriorityClass value is in system range (>= 1 billion)"
  echo "   System PriorityClasses are reserved for Kubernetes components"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PriorityClass value is in valid user-defined range"
fi

# Show priority hierarchy
echo ""
echo "📊 Priority Hierarchy:"
kubectl get priorityclasses --sort-by=.value 2>/dev/null | grep -E "NAME|payment-critical|high-priority|inventory-high|frontend-medium|analytics-low" | head -10

# Final result
echo ""
echo "═══════════════════════════════════════════════════════════"

if [ "$ERRORS" -eq 0 ]; then
  echo ""
  echo "🎉 SUCCESS - Configuration Complete!"
  echo ""
  echo "✅ All verification checks passed!"
  echo ""
  echo "📊 Configuration Summary:"
  echo "   • PriorityClass: ${PRIORITYCLASS_NAME}"
  echo "   • Value: ${EXPECTED_VALUE}"
  echo "   • Deployment: ${DEPLOYMENT_NAME} (${NAMESPACE})"
  echo ""
  echo "🛒 Holiday Flash Sale Readiness:"
  echo "   ✅ Payment services: Priority 1,000,000"
  echo "   ✅ Log forwarder: Priority 999,999 ← Your configuration"
  echo "   ✅ Other services: Lower priorities"
  echo ""
  echo "🏆 AcmeRetail Operations Team: 'Excellent work!'"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  exit 0
else
  echo ""
  echo "❌ CONFIGURATION INCOMPLETE"
  echo ""
  echo "Found ${ERRORS} error(s) in configuration"
  echo ""
  echo "💡 Review the errors above and fix the configuration."
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi
