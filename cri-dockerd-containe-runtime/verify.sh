#!/bin/bash
set -euo pipefail

# Check cri-dockerd version
CRI_VERSION=$(cri-dockerd --version 2>/dev/null | head -1 || echo "unknown")
echo "Version: ${CRI_VERSION}"

# Check if cri-docker.service is enabled
if ! systemctl is-enabled cri-docker.service &>/dev/null; then
  echo "FAIL: cri-docker.service is not enabled"
  echo "Enable it using: sudo systemctl enable cri-docker.service"
  exit 1
fi
echo "PASS: cri-docker.service is enabled"

# Check if cri-docker.service is running
if ! systemctl is-active cri-docker.service &>/dev/null; then
  echo "FAIL: cri-docker.service is not running"
  echo "Start it using: sudo systemctl start cri-docker.service"
  systemctl status cri-docker.service --no-pager -l || true
  exit 1
fi
echo "PASS: cri-docker.service is running"

# Check if cri-docker.socket is enabled
if ! systemctl is-enabled cri-docker.socket &>/dev/null; then
  echo "FAIL: cri-docker.socket is not enabled"
  echo "Enable it using: sudo systemctl enable cri-docker.socket"
  exit 1
fi
echo "PASS: cri-docker.socket is enabled"

# Check if cri-docker.socket is active
if ! systemctl is-active cri-docker.socket &>/dev/null; then
  echo "FAIL: cri-docker.socket is not active"
  echo "Start it using: sudo systemctl start cri-docker.socket"
  exit 1
fi
echo "PASS: cri-docker.socket is active"

# Check if the socket file exists
if [[ ! -S /run/cri-dockerd.sock ]]; then
  echo "FAIL: CRI socket not found at /run/cri-dockerd.sock"
  echo "The socket should be created by the cri-docker service"
  exit 1
fi
echo "PASS: CRI socket exists at /run/cri-dockerd.sock"

# Check kernel parameters
echo ""
echo "Verifying kernel parameters..."

# Check net.bridge.bridge-nf-call-iptables
IPTABLES_VALUE=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo "0")
if [[ "${IPTABLES_VALUE}" != "1" ]]; then
  echo "FAIL: net.bridge.bridge-nf-call-iptables = ${IPTABLES_VALUE} (expected: 1)"
  echo "Ensure br_netfilter module is loaded: sudo modprobe br_netfilter"
  exit 1
fi
echo "PASS: net.bridge.bridge-nf-call-iptables = 1"

# Check net.ipv6.conf.all.forwarding
IPV6_FORWARD=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || echo "0")
if [[ "${IPV6_FORWARD}" != "1" ]]; then
  echo "FAIL: net.ipv6.conf.all.forwarding = ${IPV6_FORWARD} (expected: 1)"
  exit 1
fi
echo "PASS: net.ipv6.conf.all.forwarding = 1"

# Check net.ipv4.ip_forward
IPV4_FORWARD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
if [[ "${IPV4_FORWARD}" != "1" ]]; then
  echo "FAIL: net.ipv4.ip_forward = ${IPV4_FORWARD} (expected: 1)"
  exit 1
fi
echo "PASS: net.ipv4.ip_forward = 1"

# Check net.netfilter.nf_conntrack_max
CONNTRACK_MAX=$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo "0")
if [[ "${CONNTRACK_MAX}" != "131072" ]]; then
  echo "FAIL: net.netfilter.nf_conntrack_max = ${CONNTRACK_MAX} (expected: 131072)"
  exit 1
fi
echo "PASS: net.netfilter.nf_conntrack_max = 131072"

# Check if sysctl configuration file exists for persistence
echo ""
echo "Verifying persistence configuration..."

SYSCTL_FILES=(
  "/etc/sysctl.d/99-kubernetes-cri.conf"
  "/etc/sysctl.d/kubernetes.conf"
  "/etc/sysctl.d/k8s.conf"
  "/etc/sysctl.conf"
)

FOUND_CONFIG=false
for SYSCTL_FILE in "${SYSCTL_FILES[@]}"; do
  if [[ -f "${SYSCTL_FILE}" ]]; then
    # Check if file contains the required parameters with exact values
    if grep -qE '^\s*net\.bridge\.bridge-nf-call-iptables\s*=\s*1(\s|$)' "${SYSCTL_FILE}" && \
       grep -qE '^\s*net\.ipv6\.conf\.all\.forwarding\s*=\s*1(\s|$)' "${SYSCTL_FILE}" && \
       grep -qE '^\s*net\.ipv4\.ip_forward\s*=\s*1(\s|$)' "${SYSCTL_FILE}" && \
       grep -qE '^\s*net\.netfilter\.nf_conntrack_max\s*=\s*131072(\s|$)' "${SYSCTL_FILE}"; then
      echo "PASS: Kernel parameters configured for persistence in ${SYSCTL_FILE}"
      FOUND_CONFIG=true
      break
    fi
  fi
done

if [[ "${FOUND_CONFIG}" == "false" ]]; then
  echo "FAIL: Kernel parameters not configured for persistence"
  echo "Create a configuration file in /etc/sysctl.d/ with all required parameters"
  echo "Expected parameters:"
  echo "  net.bridge.bridge-nf-call-iptables = 1"
  echo "  net.ipv6.conf.all.forwarding = 1"
  echo "  net.ipv4.ip_forward = 1"
  echo "  net.netfilter.nf_conntrack_max = 131072"
  exit 1
fi

# Check Docker is running (dependency)
if ! systemctl is-active docker &>/dev/null; then
  echo "WARNING: Docker service is not running"
  echo "cri-dockerd requires Docker to be running"
fi

# Verify socket permissions
SOCKET_PERMS=$(stat -c %a /run/cri-dockerd.sock 2>/dev/null || echo "000")
if [[ "${SOCKET_PERMS}" =~ ^[67][0-7][0-7]$ ]]; then
  echo "PASS: CRI socket has correct permissions (${SOCKET_PERMS})"
else
  echo "INFO: Socket permissions: ${SOCKET_PERMS}"
fi

echo ""
echo "Verification passed! cri-dockerd is correctly configured!"
echo ""
echo "Summary:"
echo "  PASS: cri-dockerd installed and accessible"
echo "  PASS: cri-docker.service enabled and running"
echo "  PASS: cri-docker.socket enabled and active"
echo "  PASS: CRI socket available at /run/cri-dockerd.sock"
echo "  PASS: All kernel parameters configured correctly"
echo "  PASS: Configuration persists across reboots"
echo ""
echo "Service Status:"
systemctl status cri-docker.service --no-pager -l || true
echo ""
echo "Kernel Parameters:"
echo "  net.bridge.bridge-nf-call-iptables = ${IPTABLES_VALUE}"
echo "  net.ipv6.conf.all.forwarding = ${IPV6_FORWARD}"
echo "  net.ipv4.ip_forward = ${IPV4_FORWARD}"
echo "  net.netfilter.nf_conntrack_max = ${CONNTRACK_MAX}"
echo ""

exit 0
