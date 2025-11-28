#!/bin/bash
set -e

echo "🔍 Verifying Step 2: Container Runtime Installation..."
echo ""

# Check if containerd is installed
echo "Checking containerd installation..."
if command -v containerd &> /dev/null; then
    VERSION=$(containerd --version | awk '{print $3}')
    echo "✅ containerd is installed (version: $VERSION)"
else
    echo "❌ containerd is not installed"
    exit 1
fi

# Check if containerd service is active
echo "Checking containerd service status..."
if systemctl is-active --quiet containerd; then
    echo "✅ containerd service is active"
else
    echo "❌ containerd service is not active"
    exit 1
fi

# Check if containerd is enabled
echo "Checking if containerd is enabled..."
if systemctl is-enabled --quiet containerd; then
    echo "✅ containerd is enabled to start on boot"
else
    echo "❌ containerd is not enabled"
    exit 1
fi

# Check if configuration file exists
echo "Checking containerd configuration..."
if [ -f /etc/containerd/config.toml ]; then
    echo "✅ /etc/containerd/config.toml exists"
else
    echo "❌ /etc/containerd/config.toml not found"
    exit 1
fi

# Check if SystemdCgroup is set to true
echo "Checking SystemdCgroup setting..."
if grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
    echo "✅ SystemdCgroup is set to true"
else
    echo "❌ SystemdCgroup is not set to true"
    echo "   Run: sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml"
    exit 1
fi

# Check if Docker repository is added
echo "Checking Docker repository..."
if [ -f /etc/apt/sources.list.d/docker.list ]; then
    echo "✅ Docker repository is configured"
else
    echo "❌ Docker repository not found"
    exit 1
fi

# Mark step as complete
touch /root/cluster-setup/.step2-complete

echo ""
echo "🎉 Step 2 verification passed!"
echo "✅ Container runtime (containerd) is properly installed and configured"
echo ""
echo "Proceed to Step 3: Kubernetes Components Installation ➡️"
