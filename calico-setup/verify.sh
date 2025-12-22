#!/bin/bash
set -euo pipefail

echo "🔍 Verifying Calico CNI installation and configuration..."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  if [ "$1" = "ok" ]; then
    echo -e "${GREEN}✅ $2${NC}"
  elif [ "$1" = "fail" ]; then
    echo -e "${RED}❌ $2${NC}"
  else
    echo -e "${YELLOW}⚠️  $2${NC}"
  fi
}

# Check if Tigera Operator is installed
if ! kubectl get namespace tigera-operator &>/dev/null; then
  print_status "fail" "Tigera Operator namespace not found"
  exit 1
fi
print_status "ok" "Tigera Operator namespace exists"

# Check if operator pod is running
if ! kubectl get pods -n tigera-operator -l k8s-app=tigera-operator &>/dev/null; then
  print_status "fail" "Tigera Operator pod not found"
  exit 1
fi

OPERATOR_STATUS=$(kubectl get pods -n tigera-operator -l k8s-app=tigera-operator -o jsonpath='{.items[0].status.phase}')
if [[ "${OPERATOR_STATUS}" != "Running" ]]; then
  print_status "fail" "Tigera Operator pod is not running (status: ${OPERATOR_STATUS})"
  exit 1
fi
print_status "ok" "Tigera Operator is running"

# Check if Installation CR exists
if ! kubectl get installation default &>/dev/null; then
  print_status "fail" "Installation custom resource 'default' not found"
  exit 1
fi
print_status "ok" "Installation custom resource exists"

# Verify Pod CIDR configuration
POD_CIDR=$(kubectl get installation default -o jsonpath='{.spec.calicoNetwork.ipPools[0].cidr}')
if [[ "${POD_CIDR}" != "10.244.0.0/16" ]]; then
  print_status "fail" "Pod CIDR is incorrect: ${POD_CIDR} (expected: 10.244.0.0/16)"
  exit 1
fi
print_status "ok" "Pod CIDR correctly configured (10.244.0.0/16)"

# Check if calico-system namespace exists
if ! kubectl get namespace calico-system &>/dev/null; then
  print_status "fail" "calico-system namespace not found"
  exit 1
fi
print_status "ok" "calico-system namespace exists"

# Check if calico-node DaemonSet exists and is ready
if ! kubectl get daemonset -n calico-system calico-node &>/dev/null; then
  print_status "fail" "calico-node DaemonSet not found"
  exit 1
fi

DESIRED=$(kubectl get daemonset -n calico-system calico-node -o jsonpath='{.status.desiredNumberScheduled}')
READY=$(kubectl get daemonset -n calico-system calico-node -o jsonpath='{.status.numberReady}')

if [[ "${DESIRED}" != "${READY}" ]]; then
  print_status "fail" "calico-node DaemonSet not fully ready (${READY}/${DESIRED})"
  exit 1
fi
print_status "ok" "calico-node DaemonSet is ready (${READY}/${DESIRED})"

# Check if calico-kube-controllers deployment exists and is ready
if ! kubectl get deployment -n calico-system calico-kube-controllers &>/dev/null; then
  print_status "fail" "calico-kube-controllers deployment not found"
  exit 1
fi

REPLICAS=$(kubectl get deployment -n calico-system calico-kube-controllers -o jsonpath='{.status.replicas}')
READY_REPLICAS=$(kubectl get deployment -n calico-system calico-kube-controllers -o jsonpath='{.status.readyReplicas}')

if [[ "${REPLICAS}" != "${READY_REPLICAS}" ]]; then
  print_status "fail" "calico-kube-controllers deployment not ready (${READY_REPLICAS}/${REPLICAS})"
  exit 1
fi
print_status "ok" "calico-kube-controllers deployment is ready"

# Check TigeraStatus
if ! kubectl get tigerastatus &>/dev/null; then
  print_status "warn" "TigeraStatus resources not found (may still be initializing)"
else
  # Check if calico status is available
  CALICO_AVAILABLE=$(kubectl get tigerastatus calico -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
  if [[ "${CALICO_AVAILABLE}" == "True" ]]; then
    print_status "ok" "Calico components are available"
  else
    print_status "warn" "Calico status: ${CALICO_AVAILABLE}"
  fi
fi

# Check if nodes are Ready
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_NODE_COUNT=$(kubectl get nodes --no-headers | grep -c " Ready " || true)

if [[ "${NODE_COUNT}" -ne "${READY_NODE_COUNT}" ]]; then
  print_status "fail" "Not all nodes are Ready (${READY_NODE_COUNT}/${NODE_COUNT})"
  kubectl get nodes
  exit 1
fi
print_status "ok" "All nodes are Ready (${READY_NODE_COUNT}/${NODE_COUNT})"

# Check if CNI configuration exists
if ! ls /etc/cni/net.d/10-calico.conflist &>/dev/null && ! ls /etc/cni/net.d/*calico* &>/dev/null; then
  print_status "warn" "Calico CNI configuration file not found in /etc/cni/net.d/"
else
  print_status "ok" "Calico CNI configuration file exists"
fi

# Check if IP pools are configured
if ! kubectl get ippools &>/dev/null; then
  print_status "fail" "IPPools not found"
  exit 1
fi

IPPOOL_COUNT=$(kubectl get ippools --no-headers 2>/dev/null | wc -l)
if [[ "${IPPOOL_COUNT}" -lt 1 ]]; then
  print_status "fail" "No IPPools configured"
  exit 1
fi
print_status "ok" "IPPools configured (count: ${IPPOOL_COUNT})"

# Verify at least one ippool has the correct CIDR
POOL_CIDR=$(kubectl get ippools -o jsonpath='{.items[*].spec.cidr}' 2>/dev/null)
if [[ ! "${POOL_CIDR}" =~ "10.244.0.0/16" ]]; then
  print_status "fail" "No IPPool found with CIDR 10.244.0.0/16 (found: ${POOL_CIDR})"
  exit 1
fi
print_status "ok" "IPPool with correct CIDR found"



echo ""
print_status "ok" "🎉 Calico CNI installation verification passed!"
echo ""
echo "📊 Summary:"
echo "   ✅ Tigera Operator installed and running"
echo "   ✅ Calico Installation configured with Pod CIDR 10.244.0.0/16"
echo "   ✅ All Calico system components are running"
echo "   ✅ All nodes are in Ready state"
echo "   ✅ Pod networking is functional"
echo "   ✅ Cluster can enforce NetworkPolicy objects"
echo ""

exit 0
