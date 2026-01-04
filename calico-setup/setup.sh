#!/bin/bash
set -e

echo "alias k='kubectl'" >> ~/.bashrc && source ~/.bashrc

NODE_IP="172.30.1.2"
POD_CIDR="10.244.0.0/16"
K8S_VERSION="1.34.0"

echo "Installing Kubernetes v${K8S_VERSION}..."

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set sysctl params
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt-get update
apt-get install -y containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install Kubernetes packages
apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=${K8S_VERSION}-* kubeadm=${K8S_VERSION}-* kubectl=${K8S_VERSION}-*
apt-mark hold kubelet kubeadm kubectl

# Initialize cluster
kubeadm init \
  --apiserver-advertise-address=${NODE_IP} \
  --pod-network-cidr=${POD_CIDR} \
  --kubernetes-version=${K8S_VERSION} \
  --ignore-preflight-errors=NumCPU

# Setup kubeconfig for root
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Allow scheduling on control plane (single node setup)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo ""
echo "✅ Kubernetes installation complete!"
echo "Node IP: ${NODE_IP}"
echo "Pod CIDR: ${POD_CIDR}"
echo ""
echo "⚠️  IMPORTANT: Wait at least 2 minutes before installing CNI plugin!"
echo ""
echo "📝 Next steps:"
echo "  1. Wait for cluster components to stabilize"
echo "  2. Install Calico CNI using the Tigera Operator"
echo "  3. Verify node status and pod networking"
echo ""
