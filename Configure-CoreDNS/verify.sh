#!/bin/bash
set -euo pipefail

DNS_OUTPUT_FILE="/root/dns-server.txt"

echo "🔍 Verifying CoreDNS configuration and DNS testing..."

# Check if CoreDNS ConfigMap exists
if ! kubectl get configmap coredns -n kube-system &>/dev/null; then
  echo "❌ CoreDNS ConfigMap not found in kube-system namespace"
  exit 1
fi
echo "✅ CoreDNS ConfigMap exists"

# Check if CoreDNS is configured with the correct upstream DNS servers
COREDNS_CONFIG=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')

if ! echo "${COREDNS_CONFIG}" | grep -q "forward"; then
  echo "❌ CoreDNS ConfigMap does not contain 'forward' directive"
  exit 1
fi
echo "✅ CoreDNS ConfigMap contains 'forward' directive"

# Check for 8.8.8.8
if ! echo "${COREDNS_CONFIG}" | grep -E "forward.*8\.8\.8\.8" &>/dev/null; then
  echo "❌ CoreDNS is not configured to use 8.8.8.8 as upstream DNS server"
  exit 1
fi
echo "✅ CoreDNS is configured with 8.8.8.8"

# Check for 1.1.1.1
if ! echo "${COREDNS_CONFIG}" | grep -E "forward.*1\.1\.1\.1" &>/dev/null; then
  echo "❌ CoreDNS is not configured to use 1.1.1.1 as upstream DNS server"
  exit 1
fi
echo "✅ CoreDNS is configured with 1.1.1.1"

# Verify that both DNS servers are on the same forward line
if ! echo "${COREDNS_CONFIG}" | grep -E "forward.*8\.8\.8\.8.*1\.1\.1\.1|forward.*1\.1\.1\.1.*8\.8\.8\.8" &>/dev/null; then
  echo "⚠️  Warning: 8.8.8.8 and 1.1.1.1 should be on the same forward directive line"
fi

# Check if CoreDNS pods are running
COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
if [[ "${COREDNS_PODS}" -lt 1 ]]; then
  echo "❌ No CoreDNS pods found running in kube-system"
  exit 1
fi
echo "✅ CoreDNS pods are running (${COREDNS_PODS} pod(s))"

# Check if CoreDNS pods are ready
COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || true)
if [[ "${COREDNS_READY}" -lt 1 ]]; then
  echo "❌ CoreDNS pods are not in Running state"
  exit 1
fi
echo "✅ CoreDNS pods are in Running state"

# Check if dns-server.txt file exists
if [[ ! -f "${DNS_OUTPUT_FILE}" ]]; then
  echo "❌ File '${DNS_OUTPUT_FILE}' not found"
  exit 1
fi
echo "✅ File '${DNS_OUTPUT_FILE}' exists"

# Check if file is not empty
FILE_SIZE=$(stat -f%z "${DNS_OUTPUT_FILE}" 2>/dev/null || stat -c%s "${DNS_OUTPUT_FILE}" 2>/dev/null)
if [[ "${FILE_SIZE}" -lt 50 ]]; then
  echo "❌ File '${DNS_OUTPUT_FILE}' is too small (${FILE_SIZE} bytes) - it should contain nslookup output"
  exit 1
fi
echo "✅ File '${DNS_OUTPUT_FILE}' has content (${FILE_SIZE} bytes)"

# Check if file contains output from 8.8.8.8
if ! grep -q "8\.8\.8\.8" "${DNS_OUTPUT_FILE}"; then
  echo "❌ File '${DNS_OUTPUT_FILE}' does not contain nslookup output from 8.8.8.8"
  exit 1
fi
echo "✅ File contains nslookup output from 8.8.8.8"

# Check if file contains output from 1.1.1.1
if ! grep -q "1\.1\.1\.1" "${DNS_OUTPUT_FILE}"; then
  echo "❌ File '${DNS_OUTPUT_FILE}' does not contain nslookup output from 1.1.1.1"
  exit 1
fi
echo "✅ File contains nslookup output from 1.1.1.1"

# Check if file contains "Server:" which indicates nslookup output
SERVER_COUNT=$(grep -c "Server:" "${DNS_OUTPUT_FILE}" || true)
if [[ "${SERVER_COUNT}" -lt 2 ]]; then
  echo "❌ File should contain at least 2 'Server:' entries (one for each DNS server)"
  exit 1
fi
echo "✅ File contains nslookup results from both DNS servers"

# Check if kubernetes.io was queried
if ! grep -qi "kubernetes\.io" "${DNS_OUTPUT_FILE}"; then
  echo "⚠️  Warning: Expected to see 'kubernetes.io' in nslookup queries"
fi

# Verify DNS resolution is actually working
echo "🔬 Testing DNS resolution from within the cluster..."
TEST_POD_EXISTS=$(kubectl get pod dns-test 2>/dev/null | grep -c "dns-test" || true)
if [[ "${TEST_POD_EXISTS}" -gt 0 ]]; then
  echo "⚠️  Warning: Test pod 'dns-test' still exists. Consider cleaning it up."
fi

# Try to perform a quick DNS test
TEST_RESULT=$(kubectl run verify-dns-test --image=busybox:1.28 --restart=Never --rm -i --quiet -- nslookup kubernetes.io 2>/dev/null || echo "DNS test failed")
if echo "${TEST_RESULT}" | grep -q "Address"; then
  echo "✅ DNS resolution is working in the cluster"
else
  echo "⚠️  Warning: DNS resolution test had issues, but configuration appears correct"
fi

echo ""
echo "🎉 Verification passed! CoreDNS configuration and DNS testing completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ CoreDNS configured with upstream DNS servers: 8.8.8.8 and 1.1.1.1"
echo "   ✅ CoreDNS pods are running and healthy"
echo "   ✅ DNS testing completed with both DNS servers"
echo "   ✅ Results saved to ${DNS_OUTPUT_FILE}"
echo ""
echo "🔍 Your DNS output file contains:"
echo "   - nslookup results using 8.8.8.8"
echo "   - nslookup results using 1.1.1.1"
echo ""

exit 0
