#!/bin/bash

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
ERROR_FILE="/root/auth-debug/forbidden-error.txt"

echo "🔍 Verifying kube-apiserver authorization-mode configuration..."
echo

# 1️⃣ Check that the manifest exists
if [[ ! -f "$APISERVER_MANIFEST" ]]; then
    echo "❌ kube-apiserver manifest not found at $APISERVER_MANIFEST"
    exit 1
fi

# 2️⃣ Check authorization-mode contains Node,AlwaysDeny (in that order)
AUTH_LINE=$(grep -- "--authorization-mode" "$APISERVER_MANIFEST")

echo "🔍 Found authorization-mode: $AUTH_LINE"

if ! echo "$AUTH_LINE" | grep -q "Node,AlwaysDeny"; then
    echo "❌ AlwaysDeny is not placed immediately after Node."
    exit 1
fi

# 3️⃣ Ensure RBAC is removed
if echo "$AUTH_LINE" | grep -q "RBAC"; then
    echo "❌ RBAC must be removed from the authorization-mode list."
    exit 1
fi

echo "✅ Authorization-mode configuration looks correct!"
echo

# 4️⃣ Check static pod restarted using crictl
echo "🔍 Checking kube-apiserver container status..."

if ! crictl ps | grep -q "kube-apiserver"; then
    echo "❌ kube-apiserver container not found via crictl ps."
    exit 1
fi

crictl ps | grep kube-apiserver
echo "✅ kube-apiserver is running (restart likely occurred)."
echo

# 5️⃣ Verify kubectl returns Forbidden
echo "🔍 Testing kubectl get pods denies access..."

KUBE_OUTPUT=$(kubectl get pods 2>&1)

if echo "$KUBE_OUTPUT" | grep -qi "forbidden"; then
    echo "✅ kubectl is correctly forbidden."
else
    echo "❌ kubectl did NOT return Forbidden. Output:"
    echo "$KUBE_OUTPUT"
    exit 1
fi

# 6️⃣ Check error file
echo "🔍 Checking error log file..."

if [[ ! -s "$ERROR_FILE" ]]; then
    echo "❌ Forbidden error file missing or empty: $ERROR_FILE"
    exit 1
fi

echo "📄 Error message recorded in $ERROR_FILE:"
cat "$ERROR_FILE"

echo
echo "🎉 All checks passed successfully!"
exit 0
