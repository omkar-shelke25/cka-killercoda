#!/bin/bash
set -euo pipefail

echo "Verifying CoreDNS configuration..."

BACKUP_FILE="/opt/course/16/coredns_backup.yaml"
CUSTOM_DOMAIN="killercoda.com"

# Check if backup directory exists
if [[ ! -d "/opt/course/16" ]]; then
  echo "FAIL: Directory /opt/course/16 does not exist"
  exit 1
fi
echo "PASS: Backup directory exists"

# Check if backup file exists
if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "FAIL: Backup file not found at ${BACKUP_FILE}"
  exit 1
fi
echo "PASS: Backup file exists at ${BACKUP_FILE}"

# Verify backup file contains CoreDNS configuration
if ! grep -q "kind: ConfigMap" "${BACKUP_FILE}"; then
  echo "FAIL: Backup file does not appear to be a valid ConfigMap"
  exit 1
fi

if ! grep -q "name: coredns" "${BACKUP_FILE}"; then
  echo "FAIL: Backup file does not contain coredns ConfigMap"
  exit 1
fi

if ! grep -q "namespace: kube-system" "${BACKUP_FILE}"; then
  echo "FAIL: Backup file does not contain kube-system namespace"
  exit 1
fi

if ! grep -q "Corefile:" "${BACKUP_FILE}"; then
  echo "FAIL: Backup file does not contain Corefile data"
  exit 1
fi
echo "PASS: Backup file contains valid CoreDNS ConfigMap"

# Check current CoreDNS ConfigMap
COREDNS_CONFIG=$(kubectl get configmap coredns -n kube-system -o yaml 2>/dev/null)
if [[ -z "${COREDNS_CONFIG}" ]]; then
  echo "FAIL: Could not retrieve CoreDNS ConfigMap"
  exit 1
fi
echo "PASS: CoreDNS ConfigMap exists"

# Check if custom domain is in CoreDNS configuration
if ! echo "${COREDNS_CONFIG}" | grep -q "${CUSTOM_DOMAIN}"; then
  echo "FAIL: Custom domain '${CUSTOM_DOMAIN}' not found in CoreDNS configuration"
  echo "Expected to find: kubernetes cluster.local ${CUSTOM_DOMAIN}"
  exit 1
fi
echo "PASS: Custom domain '${CUSTOM_DOMAIN}' found in CoreDNS configuration"

# Verify the kubernetes plugin line contains both domains
KUBERNETES_LINE=$(echo "${COREDNS_CONFIG}" | grep -E "^\s*kubernetes\s+" || echo "")
if [[ -z "${KUBERNETES_LINE}" ]]; then
  echo "FAIL: Could not find kubernetes plugin configuration"
  exit 1
fi

if ! echo "${KUBERNETES_LINE}" | grep -q "cluster.local"; then
  echo "FAIL: cluster.local domain not found in kubernetes plugin"
  exit 1
fi

if ! echo "${KUBERNETES_LINE}" | grep -q "${CUSTOM_DOMAIN}"; then
  echo "FAIL: ${CUSTOM_DOMAIN} domain not found in kubernetes plugin"
  exit 1
fi
echo "PASS: Both cluster.local and ${CUSTOM_DOMAIN} configured in kubernetes plugin"

# Check if CoreDNS pods are running
COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [[ "${COREDNS_PODS}" -lt 1 ]]; then
  echo "FAIL: No CoreDNS pods are running"
  kubectl get pods -n kube-system -l k8s-app=kube-dns
  exit 1
fi
echo "PASS: CoreDNS pods are running (${COREDNS_PODS} pod(s))"

# Test DNS resolution for cluster.local
echo ""
echo "Testing DNS resolution..."
echo "Test 1: Resolving kubernetes.default.svc.cluster.local"

DNS_TEST_1=$(kubectl run dns-test-1 --image=busybox:1.35 --rm -i --restart=Never --command -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "FAILED")

if echo "${DNS_TEST_1}" | grep -q "Address"; then
  echo "PASS: cluster.local domain resolves"
else
  echo "FAIL: cluster.local domain does not resolve"
  echo "Output: ${DNS_TEST_1}"
  exit 1
fi

# Test DNS resolution for custom domain
echo "Test 2: Resolving kubernetes.default.svc.${CUSTOM_DOMAIN}"

DNS_TEST_2=$(kubectl run dns-test-2 --image=busybox:1.35 --rm -i --restart=Never --command -- nslookup kubernetes.default.svc.${CUSTOM_DOMAIN} 2>/dev/null || echo "FAILED")

if echo "${DNS_TEST_2}" | grep -q "Address"; then
  echo "PASS: ${CUSTOM_DOMAIN} domain resolves"
else
  echo "FAIL: ${CUSTOM_DOMAIN} domain does not resolve"
  echo "Output: ${DNS_TEST_2}"
  echo ""
  echo "Troubleshooting:"
  echo "1. Check CoreDNS configuration: kubectl get cm coredns -n kube-system -o yaml"
  echo "2. Check CoreDNS logs: kubectl logs -n kube-system -l k8s-app=kube-dns"
  echo "3. Restart CoreDNS: kubectl rollout restart deployment coredns -n kube-system"
  exit 1
fi

# Extract IP addresses from both tests
IP_CLUSTER_LOCAL=$(echo "${DNS_TEST_1}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
IP_CUSTOM_DOMAIN=$(echo "${DNS_TEST_2}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

if [[ -n "${IP_CLUSTER_LOCAL}" && -n "${IP_CUSTOM_DOMAIN}" ]]; then
  if [[ "${IP_CLUSTER_LOCAL}" == "${IP_CUSTOM_DOMAIN}" ]]; then
    echo "PASS: Both domains resolve to the same IP (${IP_CLUSTER_LOCAL})"
  else
    echo "WARN: Domains resolve to different IPs"
    echo "  cluster.local: ${IP_CLUSTER_LOCAL}"
    echo "  ${CUSTOM_DOMAIN}: ${IP_CUSTOM_DOMAIN}"
  fi
fi

# Verify backup can be used for restoration
echo ""
echo "Verifying backup integrity..."
if kubectl apply --dry-run=client -f "${BACKUP_FILE}" &>/dev/null; then
  echo "PASS: Backup file is valid and can be used for restoration"
else
  echo "WARN: Backup file may have issues with restoration"
fi

echo ""
echo "SUCCESS: CoreDNS configuration verification passed!"
echo ""
echo "Summary:"
echo "  - Backup created: ${BACKUP_FILE}"
echo "  - Custom domain added: ${CUSTOM_DOMAIN}"
echo "  - cluster.local resolution: Working"
echo "  - ${CUSTOM_DOMAIN} resolution: Working"
echo "  - CoreDNS pods: ${COREDNS_PODS} running"
echo ""

exit 0
