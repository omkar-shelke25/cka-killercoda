#!/bin/bash
set -euo pipefail

SCRIPT_PATH="/root/list-static-pods.sh"

pass(){ echo "✅ $1"; }
fail(){ echo "❌ $1"; exit 1; }

echo "=============================================="
echo "    Verifying Static Pod Discovery Script"
echo "=============================================="
echo ""

# Check 1: Script exists
echo "🔍 Check 1: Script existence..."
[ -f "$SCRIPT_PATH" ] || fail "Script not found at $SCRIPT_PATH"
pass "Script exists at $SCRIPT_PATH"

# Check 2: Script is executable
echo ""
echo "🔍 Check 2: Script permissions..."
[ -x "$SCRIPT_PATH" ] || fail "Script is not executable. Run: chmod +x $SCRIPT_PATH"
pass "Script is executable"


# Check 4: Verify static pods exist in cluster
echo ""
echo "🔍 Check 4: Verifying static pods in cluster..."

HTTPD_EXISTS=$(kubectl get pods -n infra-space 2>/dev/null | grep -c "httpd-web-controlplane" || echo "0")
[ "$HTTPD_EXISTS" -ge 1 ] || fail "Static pod 'httpd-web-controlplane' not found in infra-space namespace"
pass "Control plane static pod exists: httpd-web-controlplane"

AI_EXISTS=$(kubectl get pods -n ai-space 2>/dev/null | grep -c "ai-apps-node01" || echo "0")
[ "$AI_EXISTS" -ge 1 ] || fail "Static pod 'ai-apps-node01' not found in ai-space namespace"
pass "Worker static pod exists: ai-apps-node01"

# Check 5: Run the script and capture output
echo ""
echo "🔍 Check 5: Running script..."
SCRIPT_OUTPUT=$("$SCRIPT_PATH" 2>&1) || fail "Script failed to execute"
[ -n "$SCRIPT_OUTPUT" ] || fail "Script produced no output"
pass "Script executed successfully"

# Check 6: Verify script output contains both static pods
echo ""
echo "🔍 Check 6: Validating output content..."

echo "$SCRIPT_OUTPUT" | grep -q "httpd-web" || fail "Output missing 'httpd-web' static pod"
pass "Output contains httpd-web static pod"

echo "$SCRIPT_OUTPUT" | grep -q "ai-apps" || fail "Output missing 'ai-apps' static pod"
pass "Output contains ai-apps static pod"

echo "$SCRIPT_OUTPUT" | grep -q "infra-space" || fail "Output missing 'infra-space' namespace"
pass "Output contains infra-space namespace"

echo "$SCRIPT_OUTPUT" | grep -q "ai-space" || fail "Output missing 'ai-space' namespace"
pass "Output contains ai-space namespace"

# Check 7: Verify both nodes are represented
echo ""
echo "🔍 Check 7: Node coverage..."

echo "$SCRIPT_OUTPUT" | grep -q "controlplane" || fail "Output missing controlplane node reference"
pass "Output includes controlplane node"

echo "$SCRIPT_OUTPUT" | grep -q "node01" || fail "Output missing node01 reference"
pass "Output includes node01 worker node"

# Check 8: Count static pods found by script
echo ""
echo "🔍 Check 8: Static pod count..."

STATIC_POD_COUNT=$(echo "$SCRIPT_OUTPUT" | grep -cE "(httpd-web|ai-apps)" || echo "0")
[ "$STATIC_POD_COUNT" -ge 2 ] || fail "Script should find at least 2 static pods (found: $STATIC_POD_COUNT)"
pass "Script found $STATIC_POD_COUNT static pods"

# Final summary
echo ""
echo "=============================================="
echo "    📊 Verification Summary"
echo "=============================================="
echo ""
echo "✅ Script Path: $SCRIPT_PATH"
echo "✅ Executable: Yes"
echo "✅ Static Pods Detected: $STATIC_POD_COUNT"
echo "✅ Namespaces Covered: infra-space, ai-space"
echo "✅ Nodes Covered: controlplane, node01"
echo ""
echo "🎉 All checks passed!"
echo ""
echo "Your script successfully identifies:"
echo "  • httpd-web-controlplane (infra-space)"
echo "  • ai-apps-node01 (ai-space)"
echo ""
echo "=============================================="
echo "    🏆 Mission Complete!"
echo "=============================================="
