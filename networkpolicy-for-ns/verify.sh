#!/bin/bash

NAMESPACE="fubar"
NETPOL_NAME="allow-port-from-namespace"

echo "Verifying NetworkPolicy Configuration..."
echo ""

ERRORS=0

# Check if NetworkPolicy exists
if ! kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
  echo "FAIL: NetworkPolicy '${NETPOL_NAME}' not found in namespace '${NAMESPACE}'"
  exit 1
fi
echo "PASS: NetworkPolicy '${NETPOL_NAME}' exists"

# Check policyTypes includes Ingress
POLICY_TYPE=$(kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.policyTypes[0]}')
if [ "$POLICY_TYPE" != "Ingress" ]; then
  echo "FAIL: policyTypes should include 'Ingress'"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: policyTypes includes Ingress"
fi

# Check podSelector (should be empty to select all pods)
POD_SELECTOR=$(kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.podSelector}')
if [ "$POD_SELECTOR" != "{}" ] && [ -n "$POD_SELECTOR" ]; then
  echo "WARN: podSelector is not empty - may not apply to all pods"
else
  echo "PASS: podSelector applies to all pods"
fi

# Check namespace selector
NS_SELECTOR=$(kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels}' 2>/dev/null)
if [ -z "$NS_SELECTOR" ]; then
  echo "FAIL: namespaceSelector not found"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: namespaceSelector configured"
  
  # Check if it matches 'internal' namespace
  NS_LABEL=$(kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels.kubernetes\.io/metadata\.name}' 2>/dev/null)
  if [ "$NS_LABEL" = "internal" ]; then
    echo "PASS: Allows traffic from 'internal' namespace"
  else
    echo "WARN: Namespace selector may not match 'internal' correctly"
  fi
fi

# Check port 9000
PORT=$(kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ingress[0].ports[0].port}')
if [ "$PORT" != "9000" ]; then
  echo "FAIL: Port is '${PORT}', expected '9000'"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: Allows traffic to port 9000"
fi

# Check protocol
PROTOCOL=$(kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ingress[0].ports[0].protocol}')
if [ "$PROTOCOL" != "TCP" ]; then
  echo "FAIL: Protocol is '${PROTOCOL}', expected 'TCP'"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: Protocol is TCP"
fi

# Test actual connectivity
echo ""
echo "Testing Network Access..."

# Test 1: internal → app-9000:9000 (should work)
if kubectl exec -n internal internal-client -- timeout 3 wget -qO- app-9000-service.fubar.svc.cluster.local:9000 >/dev/null 2>&1; then
  echo "PASS: internal namespace can access port 9000"
else
  echo "FAIL: internal namespace cannot access port 9000 (should be allowed)"
  ERRORS=$((ERRORS + 1))
fi

# Test 2: internal → app-8080:8080 (should fail)
if kubectl exec -n internal internal-client -- timeout 3 wget -qO- app-8080-service.fubar.svc.cluster.local:8080 >/dev/null 2>&1; then
  echo "FAIL: internal namespace can access port 8080 (should be blocked)"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: Port 8080 is blocked (correct)"
fi

# Test 3: external → app-9000:9000 (should fail)
if kubectl exec -n external external-client -- timeout 3 wget -qO- app-9000-service.fubar.svc.cluster.local:9000 >/dev/null 2>&1; then
  echo "FAIL: external namespace can access services (should be blocked)"
  ERRORS=$((ERRORS + 1))
else
  echo "PASS: external namespace is blocked (correct)"
fi

# Show current configuration
echo ""
echo "NetworkPolicy Configuration:"
kubectl get networkpolicy ${NETPOL_NAME} -n ${NAMESPACE}

# Final result
echo ""
echo "========================================================================"

if [ "$ERRORS" -eq 0 ]; then
  echo ""
  echo "SUCCESS - NetworkPolicy Configured Correctly"
  echo ""
  echo "All verification checks passed"
  echo ""
  echo "Access Control Summary:"
  echo "   ✅ internal namespace → port 9000 (ALLOWED)"
  echo "   ❌ internal namespace → port 8080 (BLOCKED)"
  echo "   ❌ external namespace → any port (BLOCKED)"
  echo ""
  echo "Namespace isolation is properly configured"
  echo ""
  echo "========================================================================"
  exit 0
else
  echo ""
  echo "CONFIGURATION INCOMPLETE"
  echo ""
  echo "Found ${ERRORS} error(s)"
  echo ""
  echo "========================================================================"
  exit 1
fi
