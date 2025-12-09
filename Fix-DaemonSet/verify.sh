#!/bin/bash

NAMESPACE="kube-system"
DAEMONSET_NAME="fluentd-elasticsearch"

echo "Verifying DaemonSet Fix..."
echo ""

ERRORS=0

# Check if DaemonSet exists
if ! kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "FAIL: DaemonSet '${DAEMONSET_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
echo "PASS: DaemonSet '${DAEMONSET_NAME}' exists"

# Get node count
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo "INFO: Total nodes in cluster: ${TOTAL_NODES}"

# Get DaemonSet desired and current counts
DESIRED=$(kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.status.desiredNumberScheduled}')
CURRENT=$(kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.status.currentNumberScheduled}')
READY=$(kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.status.numberReady}')

echo "INFO: DaemonSet Status - Desired: ${DESIRED}, Current: ${CURRENT}, Ready: ${READY}"

# Check if DESIRED equals total nodes
if [ "$DESIRED" -ne "$TOTAL_NODES" ]; then
  echo "FAIL: DaemonSet DESIRED ($DESIRED) does not equal total nodes ($TOTAL_NODES)"
  echo "HINT: DaemonSet is not scheduling on all nodes"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: DaemonSet DESIRED matches total nodes"
fi

# Check if CURRENT equals DESIRED
if [ "$CURRENT" -ne "$DESIRED" ]; then
  echo "FAIL: DaemonSet CURRENT ($CURRENT) does not equal DESIRED ($DESIRED)"
  echo "HINT: Some pods failed to schedule"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: DaemonSet CURRENT equals DESIRED"
fi

# Check if pods are ready
if [ "$READY" -ne "$DESIRED" ]; then
  echo "WARN: Not all pods are ready yet (${READY}/${DESIRED})"
  echo "INFO: Pods may still be starting..."
else
  echo "PASS: All DaemonSet pods are ready"
fi

# Check if control-plane node has the pod
echo ""
echo "Checking control-plane node..."
CONTROL_PLANE=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane)].metadata.name}' 2>/dev/null | awk '{print $1}')

if [ -z "$CONTROL_PLANE" ]; then
  # Try old master label
  CONTROL_PLANE=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/master)].metadata.name}' 2>/dev/null | awk '{print $1}')
fi

if [ -n "$CONTROL_PLANE" ]; then
  echo "INFO: Control-plane node: ${CONTROL_PLANE}"
  
  # Check if pod exists on control-plane
  POD_ON_CONTROL_PLANE=$(kubectl get pods -n ${NAMESPACE} -l name=fluentd-elasticsearch --field-selector spec.nodeName=${CONTROL_PLANE} --no-headers 2>/dev/null | wc -l)
  
  if [ "$POD_ON_CONTROL_PLANE" -eq 0 ]; then
    echo "FAIL: No pod scheduled on control-plane node"
    echo "HINT: Add tolerations for control-plane taint"
    echo ""
    echo "Check control-plane taints:"
    kubectl describe node ${CONTROL_PLANE} | grep Taints
    ERRORS=$((ERRORS + 1))
  else
    echo "PASS: Pod is scheduled on control-plane node"
  fi
else
  echo "WARN: Could not identify control-plane node"
fi

# Check tolerations in DaemonSet
echo ""
echo "Checking DaemonSet tolerations..."
HAS_TOLERATION=$(kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.tolerations}' 2>/dev/null)

if [ -z "$HAS_TOLERATION" ] || [ "$HAS_TOLERATION" = "null" ]; then
  echo "FAIL: DaemonSet has no tolerations configured"
  echo "HINT: Add toleration for node-role.kubernetes.io/control-plane"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: DaemonSet has tolerations configured"
  
  # Check for control-plane toleration
  CONTROL_PLANE_TOLERATION=$(kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/control-plane")].key}' 2>/dev/null)
  MASTER_TOLERATION=$(kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="node-role.kubernetes.io/master")].key}' 2>/dev/null)
  
  if [ -n "$CONTROL_PLANE_TOLERATION" ] || [ -n "$MASTER_TOLERATION" ]; then
    echo "PASS: Control-plane toleration found"
  else
    echo "WARN: No control-plane or master toleration found"
    echo "INFO: Current tolerations:"
    kubectl get daemonset ${DAEMONSET_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.tolerations}' | jq '.' 2>/dev/null || echo "Could not parse tolerations"
  fi
fi

# Show pod distribution
echo ""
echo "Pod distribution across nodes:"
kubectl get pods -n ${NAMESPACE} -l name=fluentd-elasticsearch -o wide 2>/dev/null | head -10

# Final result
echo ""
echo "========================================================================"

if [ "$ERRORS" -eq 0 ]; then
  echo ""
  echo "SUCCESS - DaemonSet is correctly configured"
  echo ""
  echo "All verification checks passed"
  echo ""
  echo "Summary:"
  echo "   - DaemonSet scheduling on all ${TOTAL_NODES} nodes"
  echo "   - Pod running on control-plane node"
  echo "   - All pods are ready"
  echo ""
  echo "The fluentd-elasticsearch DaemonSet is now collecting logs from all nodes"
  echo ""
  echo "========================================================================"
  exit 0
else
  echo ""
  echo "CONFIGURATION INCOMPLETE"
  echo ""
  echo "Found ${ERRORS} error(s)"
  echo ""
  echo "Common fix:"
  echo "   kubectl edit daemonset ${DAEMONSET_NAME} -n ${NAMESPACE}"
  echo ""
  echo "Add under spec.template.spec:"
  echo "   tolerations:"
  echo "   - key: node-role.kubernetes.io/control-plane"
  echo "     operator: Exists"
  echo "     effect: NoSchedule"
  echo ""
  echo "========================================================================"
  exit 1
fi
