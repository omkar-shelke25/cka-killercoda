#!/bin/bash
set -euo pipefail

echo "Setting up kubeconfig extraction scenario with real certificates..."

# Create directory structure
mkdir -p /opt/course/1

# Generate CA certificate
openssl genrsa -out /tmp/ca.key 2048 2>/dev/null
openssl req -x509 -new -nodes -key /tmp/ca.key -sha256 -days 365 -out /tmp/ca.crt \
  -subj "/CN=kubernetes" 2>/dev/null

# Generate account-0027 certificate
openssl genrsa -out /tmp/account-0027.key 2048 2>/dev/null
openssl req -new -key /tmp/account-0027.key -out /tmp/account-0027.csr \
  -subj "/O=system:masters/CN=account-0027" 2>/dev/null
openssl x509 -req -in /tmp/account-0027.csr -CA /tmp/ca.crt -CAkey /tmp/ca.key \
  -CAcreateserial -out /tmp/account-0027.crt -days 365 -sha256 2>/dev/null

# Generate kubernetes-admin certificate
openssl genrsa -out /tmp/kubernetes-admin.key 2048 2>/dev/null
openssl req -new -key /tmp/kubernetes-admin.key -out /tmp/kubernetes-admin.csr \
  -subj "/O=system:masters/CN=kubernetes-admin" 2>/dev/null
openssl x509 -req -in /tmp/kubernetes-admin.csr -CA /tmp/ca.crt -CAkey /tmp/ca.key \
  -CAcreateserial -out /tmp/kubernetes-admin.crt -days 365 -sha256 2>/dev/null

# Encode certificates to base64 (single line)
CA_BASE64=$(cat /tmp/ca.crt | base64 -w 0)
ACCOUNT_CERT_BASE64=$(cat /tmp/account-0027.crt | base64 -w 0)
ACCOUNT_KEY_BASE64=$(cat /tmp/account-0027.key | base64 -w 0)
ADMIN_CERT_BASE64=$(cat /tmp/kubernetes-admin.crt | base64 -w 0)
ADMIN_KEY_BASE64=$(cat /tmp/kubernetes-admin.key | base64 -w 0)

# Generate a complete kubeconfig with multiple contexts and users
cat > /opt/course/1/kubeconfig <<EOF
apiVersion: v1
kind: Config
current-context: kubernetes-admin@kubernetes
clusters:
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://cluster1.example.com:6443
  name: cluster1
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://10.96.0.1:6443
  name: kubernetes
- cluster:
    certificate-authority-data: ${CA_BASE64}
    server: https://staging.example.com:6443
  name: staging
contexts:
- context:
    cluster: cluster1
    user: admin
  name: admin@cluster1
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
- context:
    cluster: staging
    user: developer
  name: developer@staging
- context:
    cluster: cluster1
    user: account-0027
  name: account-0027@cluster1
users:
- name: admin
  user:
    client-certificate-data: ${ADMIN_CERT_BASE64}
    client-key-data: ${ADMIN_KEY_BASE64}
- name: kubernetes-admin
  user:
    client-certificate-data: ${ADMIN_CERT_BASE64}
    client-key-data: ${ADMIN_KEY_BASE64}
- name: developer
  user:
    token: eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5LWlkIn0.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImRldmVsb3Blci10b2tlbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJkZXZlbG9wZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIxMjM0NTY3OC05YWJjLWRlZi'+str(hash('developer-token'))[-20:]+'IsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmRldmVsb3BlciJ9.DUMMY_SIGNATURE_NOT_VALID_FOR_PRODUCTION_USE_ONLY_FOR_KUBECONFIG_EXAMPLE
- name: account-0027
  user:
    client-certificate-data: ${ACCOUNT_CERT_BASE64}
    client-key-data: ${ACCOUNT_KEY_BASE64}
EOF

# Set proper permissions
chmod 600 /opt/course/1/kubeconfig

echo ""
echo "✅ Setup complete!"
echo ""
echo "📁 Created: /opt/course/1/kubeconfig"
echo ""
echo "📋 Kubeconfig contains:"
echo "   - 4 contexts: admin@cluster1, kubernetes-admin@kubernetes, developer@staging, account-0027@cluster1"
echo "   - 3 clusters: cluster1, kubernetes, staging"
echo "   - Current context: kubernetes-admin@kubernetes"
echo "   - User account-0027 with real client certificate (base64 encoded)"
echo ""
echo "🔐 Certificates generated:"
echo "   - CA certificate (for all clusters)"
echo "   - account-0027 certificate (O=system:masters, CN=account-0027)"
echo "   - kubernetes-admin certificate (O=system:masters, CN=kubernetes-admin)"
echo ""
echo "📝 Your task:"
echo "   1. Extract all context names → /opt/course/1/contexts"
echo "   2. Extract current context → /opt/course/1/current-context"
echo "   3. Decode account-0027 certificate → /opt/course/1/cert"
echo ""
echo "💡 Hint: Use 'kubectl config view' or parse the YAML directly"
echo "   For certificate decoding: base64 -d"
echo ""

# Cleanup temporary files
rm -f /tmp/ca.key /tmp/ca.crt /tmp/ca.srl
rm -f /tmp/account-0027.key /tmp/account-0027.crt /tmp/account-0027.csr
rm -f /tmp/kubernetes-admin.key /tmp/kubernetes-admin.crt /tmp/kubernetes-admin.csr

echo "🧹 Temporary certificate files cleaned up"
echo ""
