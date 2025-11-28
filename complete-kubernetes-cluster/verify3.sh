#!/bin/bash
set -e

echo "🔍 Verifying Step 3: Kubernetes Components Installation..."
echo ""

# Check if kubeadm is installed
echo "Checking kubeadm..."
if command -v kubeadm &> /dev/null; then
    KUBEADM_VERSION=$(kubeadm version -o short)
    echo "✅ kubeadm is installed (version: $KUBEADM_VERSION)"
else
    echo "❌ kubeadm is not installed"
    exit 1
fi

# Check if kubectl is installed
echo "Checking kubectl..."
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep gitVersion | cut -d'"' -f4)
    echo "✅ kubectl is installed (version: $KUBECTL_VERSION)"
else
    echo "❌ kubectl is not installed"
    exit 1
fi

# Check if kubelet is installed
echo "Checking kubelet..."
if command -v kubelet &> /dev/null; then
    KUBELET_VERSION=$(kubelet --version | awk '{print $2}')
    echo "✅ kubelet is installed (version: $KUBELET_VERSION)"
else
    echo "❌ kubelet is not installed"
    exit 1
fi

# Check if packages are on hold
echo "Checking if packages are held..."
HELD_PACKAGES=$(apt-mark showhold | grep -E '^(kubeadm|kubelet|kubectl)$' | wc -l)
if [ "$HELD_PACKAGES" -eq 3 ]; then
    echo "✅ All Kubernetes packages are held"
else
    echo "❌ Not all Kubernetes packages are held (found $HELD_PACKAGES/3)"
    echo "   Run: sudo apt-mark hold kubelet kubeadm kubectl"
    exit 1
fi

# Check if kubelet service is enabled
echo "Checking kubelet service..."
if systemctl is-enabled --quiet kubelet; then
    echo "✅ kubelet service is enabled"
else
    echo "❌ kubelet service is not enabled"
    exit 1
fi

# Check if Kubernetes repository is added
echo "Checking Kubernetes repository..."
if [ -f /etc/apt/sources.list.d/kubernetes.list ]; then
    echo "✅ Kubernetes repository is configured"
else
    echo "❌ Kubernetes repository not found"
    exit 1
fi

# Check if GPG key exists
echo "Checking Kubernetes GPG key..."
if [ -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
    echo "✅ Kubernetes GPG key is installed"
else
    echo "❌ Kubernetes GPG key not found"
    exit 1
fi

# Mark step as complete
touch /root/cluster-setup/.step3-complete

echo ""
echo "🎉 Step 3 verification passed!"
echo "✅ All Kubernetes components are properly installed"
echo ""
echo "Proceed to Step 4: Initialize Master Node ➡️"
