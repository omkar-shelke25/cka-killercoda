#!/bin/bash
set -euo pipefail

echo "🔧 Setting up cri-dockerd configuration environment..."


# Download cri-dockerd package
echo "📥 Downloading cri-dockerd package..."
cd ~
wget -q https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.21/cri-dockerd_0.3.21.3-0.ubuntu-bionic_amd64.deb -O cri-dockerd.deb

