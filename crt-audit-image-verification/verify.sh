#!/bin/bash
set -euo pipefail

# CKA Certificate Audit & Control-Plane Image Verification - Verification Script
# This script validates that all required tasks have been completed correctly

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REQUIRED_FILES=(
    "/k8s/cert-details-old.txt"
    "/k8s/cert-details-new.txt"
    "/k8s/image-list.txt"
)

TASK_PASSED=0
TASK_FAILED=0

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 CKA Certificate Audit Verification${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to print pass/fail
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TASK_PASSED++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((TASK_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Verify control-plane access
echo -e "${BLUE}📋 Verifying Control-Plane Environment${NC}"
echo "─────────────────────────────────────────"

if [[ -d /etc/kubernetes/pki ]]; then
    check_pass "Control-plane PKI directory found"
else
    check_fail "Control-plane PKI directory not found - must run on control-plane node"
    exit 1
fi

if command -v kubeadm &>/dev/null; then
    KUBEADM_VER=$(kubeadm version -o short)
    check_pass "kubeadm available (version: $KUBEADM_VER)"
else
    check_fail "kubeadm command not found"
    exit 1
fi

if command -v kubectl &>/dev/null; then
    check_pass "kubectl available"
else
    check_fail "kubectl command not found"
    exit 1
fi

echo ""
echo -e "${BLUE}📁 Verifying Output Files${NC}"
echo "─────────────────────────────────────────"

# Verify all required files exist
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        check_pass "File exists: $file (${SIZE} bytes)"
    else
        check_fail "File missing: $file"
    fi
done

echo ""
echo -e "${BLUE}📊 Task 1: Certificate Audit (Initial)${NC}"
echo "─────────────────────────────────────────"

# Verify cert-details-old.txt content
if [[ -f /k8s/cert-details-old.txt ]]; then
    # Check for required content
    if grep -q "CERTIFICATE" /k8s/cert-details-old.txt; then
        check_pass "cert-details-old.txt contains certificate information"
    else
        check_fail "cert-details-old.txt missing certificate details"
    fi
    
    if grep -q "EXPIRES" /k8s/cert-details-old.txt || grep -q "UTC" /k8s/cert-details-old.txt; then
        check_pass "cert-details-old.txt contains expiration information"
    else
        check_fail "cert-details-old.txt missing expiration dates"
    fi
    
    if grep -q "apiserver" /k8s/cert-details-old.txt; then
        check_pass "cert-details-old.txt includes apiserver certificate"
    else
        check_warn "cert-details-old.txt might not include all certificates"
    fi
    
    # Count certificates mentioned
    CERT_COUNT=$(grep -c "\.crt" /k8s/cert-details-old.txt || echo "0")
    if [[ ${CERT_COUNT} -gt 0 ]]; then
        check_pass "cert-details-old.txt mentions ${CERT_COUNT} certificates"
    fi
    
    # Check for timestamp
    if grep -q "Date\|date\|UTC\|2024\|2025" /k8s/cert-details-old.txt; then
        check_pass "cert-details-old.txt contains timestamp information"
    else
        check_warn "cert-details-old.txt might not contain clear timestamp"
    fi
fi

echo ""
echo -e "${BLUE}🔄 Task 2: Certificate Renewal and Audit${NC}"
echo "─────────────────────────────────────────"

# Verify cert-details-new.txt content
if [[ -f /k8s/cert-details-new.txt ]]; then
    # Check for required content
    if grep -q "CERTIFICATE" /k8s/cert-details-new.txt; then
        check_pass "cert-details-new.txt contains certificate information"
    else
        check_fail "cert-details-new.txt missing certificate details"
    fi
    
    if grep -q "EXPIRES" /k8s/cert-details-new.txt || grep -q "UTC" /k8s/cert-details-new.txt; then
        check_pass "cert-details-new.txt contains expiration information"
    else
        check_fail "cert-details-new.txt missing expiration dates"
    fi
    
    # Count certificates
    CERT_COUNT_NEW=$(grep -c "\.crt" /k8s/cert-details-new.txt || echo "0")
    if [[ ${CERT_COUNT_NEW} -gt 0 ]]; then
        check_pass "cert-details-new.txt mentions ${CERT_COUNT_NEW} certificates"
    fi
    
    # Check that files are different (indicating renewal occurred)
    if ! diff /k8s/cert-details-old.txt /k8s/cert-details-new.txt > /dev/null 2>&1; then
        check_pass "Certificate files differ (renewal detected)"
    else
        check_warn "cert-details-old.txt and cert-details-new.txt are identical"
    fi
    
    # Check for renewal indicators
    if grep -q "POST-RENEWAL\|post-renewal\|After Renewal\|renewed" /k8s/cert-details-new.txt; then
        check_pass "cert-details-new.txt marked as post-renewal"
    else
        check_warn "cert-details-new.txt doesn't explicitly indicate post-renewal status"
    fi
fi

echo ""
echo -e "${BLUE}📦 Task 3: Control-Plane Images Documentation${NC}"
echo "─────────────────────────────────────────"

# Verify image-list.txt content
if [[ -f /k8s/image-list.txt ]]; then
    # Check for required content
    if grep -q "CONTROL-PLANE\|image\|Image\|docker\|registry\|kube-apiserver\|kube-controller-manager\|kube-scheduler\|etcd" /k8s/image-list.txt; then
        check_pass "image-list.txt contains control-plane image information"
    else
        check_fail "image-list.txt missing image details"
    fi
    
    # Check for k8s images
    if grep -qE "kube-apiserver|kube-controller-manager|kube-scheduler|kube-proxy|etcd|coredns" /k8s/image-list.txt; then
        check_pass "image-list.txt includes standard control-plane components"
    else
        check_warn "image-list.txt might be missing standard components"
    fi
    
    # Check for version info
    if grep -qE "[0-9]+\.[0-9]+\.[0-9]+|v[0-9]|registry\.k8s\.io" /k8s/image-list.txt; then
        check_pass "image-list.txt contains version and registry information"
    else
        check_warn "image-list.txt might lack version specifics"
    fi
    
    # Check for documentation
    if grep -q "kubeadm\|version\|kubernetes\|Date" /k8s/image-list.txt; then
        check_pass "image-list.txt includes documentation headers"
    else
        check_warn "image-list.txt could include more documentation"
    fi
    
    # Count images
    IMAGE_COUNT=$(grep -cE "k8s\.gcr\.io|registry\.k8s\.io|gcr\.io" /k8s/image-list.txt || echo "0")
    if [[ ${IMAGE_COUNT} -gt 0 ]]; then
        check_pass "image-list.txt lists ${IMAGE_COUNT} image references"
    fi
fi

echo ""
echo -e "${BLUE}🏥 Cluster Health Verification${NC}"
echo "─────────────────────────────────────────"

# Verify cluster is healthy
if kubectl get nodes > /dev/null 2>&1; then
    READY_NODES=$(kubectl get nodes --no-headers | grep -c " Ready " || echo "0")
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    if [[ ${READY_NODES} -gt 0 ]]; then
        check_pass "Cluster nodes operational (${READY_NODES}/${TOTAL_NODES} ready)"
    else
        check_fail "No nodes in Ready state"
    fi
else
    check_warn "Cannot verify cluster connectivity"
fi

# Verify control-plane components
if kubectl get pods -n kube-system -o name 2>/dev/null | grep -q "kube-apiserver"; then
    RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    check_pass "Control-plane components present (${RUNNING_PODS} pods running)"
else
    check_warn "Cannot verify control-plane components"
fi

echo ""
echo -e "${BLUE}📝 File Content Summary${NC}"
echo "─────────────────────────────────────────"

echo "cert-details-old.txt (lines): $(wc -l < /k8s/cert-details-old.txt 2>/dev/null || echo 'N/A')"
echo "cert-details-new.txt (lines): $(wc -l < /k8s/cert-details-new.txt 2>/dev/null || echo 'N/A')"
echo "image-list.txt (lines): $(wc -l < /k8s/image-list.txt 2>/dev/null || echo 'N/A')"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Verification Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Passed: ${TASK_PASSED}${NC}"
echo -e "${RED}❌ Failed: ${TASK_FAILED}${NC}"
echo ""

if [[ ${TASK_FAILED} -eq 0 ]]; then
    echo -e "${GREEN}🎉 All verification checks passed!${NC}"
    echo -e "${GREEN}Certificate audit and control-plane image inventory complete.${NC}"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Review audit reports in /k8s/"
    echo "  2. Verify certificate renewal dates are correct"
    echo "  3. Validate control-plane images for compliance"
    echo "  4. Archive audit files for compliance records"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️  Some verification checks failed.${NC}"
    echo "Please review the output above and complete any missing tasks."
    echo ""
    exit 1
fi
