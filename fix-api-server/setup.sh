#!/bin/bash
set -e

CERT_DIR="/etc/kubernetes/pki"
KEY_FILE="$CERT_DIR/apiserver.key"
CRT_FILE="$CERT_DIR/apiserver.crt"

echo "=============================================="
echo " Simulating Certificate Rotation Failure"
echo " WARNING: This will break the API server!"
echo "=============================================="
sleep 2

# ----------------------------------------------------------
# 1. Delete cert + key
# ----------------------------------------------------------
echo "[+] Deleting API server certificate and key..."
if [ -f "$KEY_FILE" ]; then
    sudo rm -f "$KEY_FILE"
    echo "[+] Deleted: $KEY_FILE"
else
    echo "[!] Key file already missing: $KEY_FILE"
fi

if [ -f "$CRT_FILE" ]; then
    sudo rm -f "$CRT_FILE"
    echo "[+] Deleted: $CRT_FILE"
else
    echo "[!] Cert file already missing: $CRT_FILE"
fi

# ----------------------------------------------------------
# 2. Find the kube-apiserver container
# ----------------------------------------------------------
echo "[+] Finding kube-apiserver container ID..."
CID=$(sudo crictl ps -a --name kube-apiserver -q | head -n 1)

if [ -z "$CID" ]; then
    echo "[!] No kube-apiserver container found."
    exit 0
fi

echo "[+] Found container: $CID"

# ----------------------------------------------------------
# 3. Stop container
# ----------------------------------------------------------
echo "[+] Stopping kube-apiserver container..."
sudo crictl stop $CID 2>/dev/null || true
sleep 2

# ----------------------------------------------------------
# 4. Remove container
# ----------------------------------------------------------
echo "[+] Removing kube-apiserver container..."
sudo crictl rm $CID 2>/dev/null || true
sleep 2

echo "[+] kube-apiserver container removed."

# ----------------------------------------------------------
# 5. Wait for crash loop to begin
# ----------------------------------------------------------
echo "[+] Waiting for kube-apiserver to enter CrashLoopBackOff..."
sleep 5

# ----------------------------------------------------------
# 6. Report status
# ----------------------------------------------------------
echo ""
echo "=============================================="
echo " SCENARIO READY"
echo "=============================================="
echo ""
echo "Current Status:"
echo "  ❌ API server certificates deleted"
echo "  ❌ kube-apiserver in CrashLoopBackOff"
echo "  ❌ kubectl is not functional"
echo ""
echo "Your Mission:"
echo "  ✅ Regenerate the missing certificates"
echo "  ✅ Restore API server functionality"
echo "  ✅ Verify cluster is operational"
echo ""
echo "=============================================="
echo ""

# Try to show the broken state (this will likely fail)
echo "Attempting kubectl (this should fail):"
kubectl get nodes 2>&1 || echo "[Expected] kubectl is not working"
echo ""

echo "Setup complete. Good luck, Engineer! 🚀"
