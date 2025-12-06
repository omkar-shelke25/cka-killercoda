#!/bin/bash
set -e

echo "🔍 Verifying Step 1: System Preparation..."
echo ""

mkdir  /root/cluster-setup/

# Check if swap is disabled
echo "Checking swap status..."
SWAP_STATUS=$(free -m | grep Swap | awk '{print $2}')
if [ "$SWAP_STATUS" -eq 0 ]; then
    echo "✅ Swap is disabled"
else
    echo "❌ Swap is still enabled (found ${SWAP_STATUS}MB)"
    exit 1
fi

# Check if modules are loaded
echo "Checking kernel modules..."
if lsmod | grep -q br_netfilter; then
    echo "✅ br_netfilter module is loaded"
else
    echo "❌ br_netfilter module is not loaded"
    exit 1
fi

if lsmod | grep -q overlay; then
    echo "✅ overlay module is loaded"
else
    echo "❌ overlay module is not loaded"
    exit 1
fi

# Check kernel parameters
echo "Checking sysctl parameters..."
BRIDGE_NF_IPTABLES=$(sysctl -n net.bridge.bridge-nf-call-iptables)
BRIDGE_NF_IP6TABLES=$(sysctl -n net.bridge.bridge-nf-call-ip6tables)
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)

if [ "$BRIDGE_NF_IPTABLES" -eq 1 ]; then
    echo "✅ net.bridge.bridge-nf-call-iptables = 1"
else
    echo "❌ net.bridge.bridge-nf-call-iptables is not set to 1"
    exit 1
fi

if [ "$BRIDGE_NF_IP6TABLES" -eq 1 ]; then
    echo "✅ net.bridge.bridge-nf-call-ip6tables = 1"
else
    echo "❌ net.bridge.bridge-nf-call-ip6tables is not set to 1"
    exit 1
fi

if [ "$IP_FORWARD" -eq 1 ]; then
    echo "✅ net.ipv4.ip_forward = 1"
else
    echo "❌ net.ipv4.ip_forward is not set to 1"
    exit 1
fi

# Check if configuration files exist
echo "Checking configuration files..."
if [ -f /etc/modules-load.d/k8s.conf ]; then
    echo "✅ /etc/modules-load.d/k8s.conf exists"
else
    echo "❌ /etc/modules-load.d/k8s.conf not found"
    exit 1
fi

if [ -f /etc/sysctl.d/k8s.conf ]; then
    echo "✅ /etc/sysctl.d/k8s.conf exists"
else
    echo "❌ /etc/sysctl.d/k8s.conf not found"
    exit 1
fi

# Mark step as complete
touch /root/cluster-setup/.step1-complete

echo ""
echo "🎉 Step 1 verification passed!"
echo "✅ All system prerequisites are configured correctly"
echo ""
echo "Proceed to Step 2: Container Runtime Installation ➡️"
