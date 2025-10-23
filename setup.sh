#!/bin/bash
# Deploy exactly two static pods:
#  - control-plane: /etc/kubernetes/manifests/httpd-web.yaml  (namespace: infra-space)
#  - node01:        /etc/kubernetes/manifests/ai-apps.yaml    (namespace: ai-space)
#
# Run this on the control-plane. It will SSH to node01 to write the worker manifest.

set -euo pipefail

WORKER_HOST="node01"
WORKER_SSH_USER="root"
WORKER_MANIFEST_DIR="/etc/kubernetes/manifests"
CONTROLPLANE_MANIFEST_DIR="/etc/kubernetes/manifests"

echo "🚀 Setting up static pods for CKA scenario..."
echo "▶ Deploying static pods on control-plane and worker nodes..."

# 1) Create namespaces
echo "1) Creating namespaces on the cluster..."
kubectl create namespace infra-space --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
kubectl create namespace ai-space --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
echo "✅ Namespaces created: infra-space, ai-space"

# 2) Write static pod manifest on CONTROL-PLANE
echo "2) Writing static pod manifest for httpd-web on control-plane..."
cat > /tmp/httpd-web.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: httpd-web
  namespace: infra-space
  labels:
    app: httpd-web
    tier: frontend
spec:
  containers:
  - name: httpd
    image: public.ecr.aws/docker/library/httpd:alpine
    ports:
    - containerPort: 80
EOF

sudo cp /tmp/httpd-web.yaml "${CONTROLPLANE_MANIFEST_DIR}/httpd-web.yaml"
sudo chmod 644 "${CONTROLPLANE_MANIFEST_DIR}/httpd-web.yaml"
echo "✅ Deployed: ${CONTROLPLANE_MANIFEST_DIR}/httpd-web.yaml (control-plane static pod)"

# 3) Create worker manifest directory if missing and write worker static pod
echo "3) Writing static pod manifest for ai-apps on worker ${WORKER_HOST}..."

# Setup SSH key if not already done
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -q
fi

# Copy SSH key to worker (may already be setup in killercoda)
ssh-keyscan -H ${WORKER_HOST} >> /root/.ssh/known_hosts 2>/dev/null || true
sshpass -p "root" ssh-copy-id -o StrictHostKeyChecking=no ${WORKER_SSH_USER}@${WORKER_HOST} 2>/dev/null || true

# Deploy static pod on worker node
ssh -o StrictHostKeyChecking=no ${WORKER_SSH_USER}@${WORKER_HOST} bash <<'REMOTE_SCRIPT'
set -euo pipefail

WORKER_MANIFEST_DIR="/etc/kubernetes/manifests"

# Ensure directory exists
if [ ! -d "${WORKER_MANIFEST_DIR}" ]; then
  echo "Creating ${WORKER_MANIFEST_DIR} on worker..."
  mkdir -p "${WORKER_MANIFEST_DIR}"
  chmod 755 "${WORKER_MANIFEST_DIR}"
fi

# Write the static pod manifest
cat > "${WORKER_MANIFEST_DIR}/ai-apps.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ai-apps
  namespace: ai-space
  labels:
    app: ai-apps
    tier: backend
spec:
  containers:
  - name: nginx
    image: public.ecr.aws/nginx/nginx:stable-perl
    ports:
    - containerPort: 80
EOF

chmod 644 "${WORKER_MANIFEST_DIR}/ai-apps.yaml"
echo "✅ Deployed: ${WORKER_MANIFEST_DIR}/ai-apps.yaml (worker static pod)"
REMOTE_SCRIPT

