#!/bin/bash
set -euo pipefail

USER="siddhi.shelke01"
NAMESPACE="game-dev"
ROLE="dev-access-role"
ROLEBINDING="siddhi-dev-binding"
CONTEXT="siddhi-mecha-dev"
CLUSTER="mecha-pulse-game-dev"
WORKDIR="/root/gameforge-onboarding"

echo "🔍 Verifying GameForge Studios User Onboarding Configuration..."
echo ""

# Track verification status
PASSED=0
TOTAL=0

# Helper function for checks
check_step() {
  local description=$1
  TOTAL=$((TOTAL + 1))
  echo -n "Checking: $description... "
}

pass_step() {
  PASSED=$((PASSED + 1))
  echo "✅"
}

fail_step() {
  local error_msg=$1
  echo "❌"
  echo "   Error: $error_msg"
}

# 1. Check private key exists and has correct permissions
check_step "Private key file exists"
if [[ -f "${WORKDIR}/siddhi.shelke01.key" ]]; then
  # Check if it's a valid RSA key
  if openssl rsa -in "${WORKDIR}/siddhi.shelke01.key" -check -noout &>/dev/null; then
    # Check key size (should be 4096 bits)
    KEY_SIZE=$(openssl rsa -in "${WORKDIR}/siddhi.shelke01.key" -text -noout 2>/dev/null | grep "Private-Key:" | grep -oE '[0-9]+')
    if [[ "$KEY_SIZE" == "4096" ]]; then
      pass_step
    else
      fail_step "Key size is $KEY_SIZE bits, expected 4096 bits"
    fi
  else
    fail_step "File exists but is not a valid RSA private key"
  fi
else
  fail_step "Private key file not found at ${WORKDIR}/siddhi.shelke01.key"
fi

# 2. Check CSR exists and has correct subject
check_step "Certificate Signing Request (CSR) exists and has correct subject"
if [[ -f "${WORKDIR}/siddhi.shelke01.csr" ]]; then
  CSR_SUBJECT=$(openssl req -in "${WORKDIR}/siddhi.shelke01.csr" -noout -subject 2>/dev/null)
  if echo "$CSR_SUBJECT" | grep -q "CN.*=.*siddhi.shelke01" && echo "$CSR_SUBJECT" | grep -q "O.*=.*gameforge-studios"; then
    pass_step
  else
    fail_step "CSR subject incorrect. Expected CN=siddhi.shelke01, O=gameforge-studios. Got: $CSR_SUBJECT"
  fi
else
  fail_step "CSR file not found at ${WORKDIR}/siddhi.shelke01.csr"
fi

# 3. Check signed certificate exists and is valid
check_step "Signed certificate exists and is valid"
if [[ -f "${WORKDIR}/siddhi.shelke01.crt" ]]; then
  # Verify certificate is signed by Kubernetes CA
  if openssl verify -CAfile /etc/kubernetes/pki/ca.crt "${WORKDIR}/siddhi.shelke01.crt" &>/dev/null; then
    # Check certificate subject
    CERT_SUBJECT=$(openssl x509 -in "${WORKDIR}/siddhi.shelke01.crt" -noout -subject 2>/dev/null)
    if echo "$CERT_SUBJECT" | grep -q "CN.*=.*siddhi.shelke01" && echo "$CERT_SUBJECT" | grep -q "O.*=.*gameforge-studios"; then
      pass_step
    else
      fail_step "Certificate subject incorrect. Expected CN=siddhi.shelke01, O=gameforge-studios"
    fi
  else
    fail_step "Certificate is not signed by Kubernetes CA or is invalid"
  fi
else
  fail_step "Certificate file not found at ${WORKDIR}/siddhi.shelke01.crt"
fi

# 4. Check user exists in kubeconfig
check_step "User '${USER}' exists in kubeconfig"
if kubectl config get-users | grep -q "^${USER}$"; then
  # Verify user has correct certificate and key configured
  USER_CERT=$(kubectl config view --raw -o jsonpath="{.users[?(@.name=='${USER}')].user.client-certificate}")
  USER_KEY=$(kubectl config view --raw -o jsonpath="{.users[?(@.name=='${USER}')].user.client-key}")
  
  if [[ -n "$USER_CERT" ]] && [[ -n "$USER_KEY" ]]; then
    pass_step
  else
    fail_step "User exists but client-certificate or client-key not configured"
  fi
else
  fail_step "User '${USER}' not found in kubeconfig"
fi

# 5. Check context exists and is correctly configured
check_step "Context '${CONTEXT}' exists and is correctly configured"
if kubectl config get-contexts "${CONTEXT}" &>/dev/null; then
  CONTEXT_CLUSTER=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CONTEXT}')].context.cluster}")
  CONTEXT_USER=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CONTEXT}')].context.user}")
  CONTEXT_NAMESPACE=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CONTEXT}')].context.namespace}")
  
  if [[ "$CONTEXT_CLUSTER" == "$CLUSTER" ]] && [[ "$CONTEXT_USER" == "$USER" ]] && [[ "$CONTEXT_NAMESPACE" == "$NAMESPACE" ]]; then
    pass_step
  else
    fail_step "Context configuration incorrect. Expected cluster=${CLUSTER}, user=${USER}, namespace=${NAMESPACE}"
  fi
else
  fail_step "Context '${CONTEXT}' not found"
fi

# 6. Check namespace exists
check_step "Namespace '${NAMESPACE}' exists"
if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  pass_step
else
  fail_step "Namespace '${NAMESPACE}' not found"
fi

# 7. Check Role exists with correct permissions
check_step "Role '${ROLE}' exists with correct permissions"
if kubectl get role "${ROLE}" -n "${NAMESPACE}" &>/dev/null; then
  # Check verbs
  ROLE_VERBS=$(kubectl get role "${ROLE}" -n "${NAMESPACE}" -o jsonpath='{.rules[*].verbs[*]}')
  for verb in get list watch; do
    if ! echo "$ROLE_VERBS" | grep -q "$verb"; then
      fail_step "Role missing verb: $verb"
      continue 2
    fi
  done
  
  # Check resources
  ROLE_RESOURCES=$(kubectl get role "${ROLE}" -n "${NAMESPACE}" -o jsonpath='{.rules[*].resources[*]}')
  for resource in pods deployments; do
    if ! echo "$ROLE_RESOURCES" | grep -q "$resource"; then
      fail_step "Role missing resource: $resource"
      continue 2
    fi
  done
  
  pass_step
else
  fail_step "Role '${ROLE}' not found in namespace '${NAMESPACE}'"
fi

# 8. Check RoleBinding exists and binds correctly
check_step "RoleBinding '${ROLEBINDING}' exists and binds correctly"
if kubectl get rolebinding "${ROLEBINDING}" -n "${NAMESPACE}" &>/dev/null; then
  BINDING_ROLE=$(kubectl get rolebinding "${ROLEBINDING}" -n "${NAMESPACE}" -o jsonpath='{.roleRef.name}')
  BINDING_USER=$(kubectl get rolebinding "${ROLEBINDING}" -n "${NAMESPACE}" -o jsonpath='{.subjects[0].name}')
  BINDING_KIND=$(kubectl get rolebinding "${ROLEBINDING}" -n "${NAMESPACE}" -o jsonpath='{.subjects[0].kind}')
  
  if [[ "$BINDING_ROLE" == "$ROLE" ]] && [[ "$BINDING_USER" == "$USER" ]] && [[ "$BINDING_KIND" == "User" ]]; then
    pass_step
  else
    fail_step "RoleBinding configuration incorrect. Expected role=${ROLE}, user=${USER}, kind=User"
  fi
else
  fail_step "RoleBinding '${ROLEBINDING}' not found in namespace '${NAMESPACE}'"
fi

# 9. Verify user has correct read permissions
check_step "User has permission to list pods in ${NAMESPACE}"
if kubectl auth can-i list pods -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User cannot list pods in namespace ${NAMESPACE}"
fi

check_step "User has permission to list deployments in ${NAMESPACE}"
if kubectl auth can-i list deployments -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User cannot list deployments in namespace ${NAMESPACE}"
fi

check_step "User has permission to watch pods in ${NAMESPACE}"
if kubectl auth can-i watch pods -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User cannot watch pods in namespace ${NAMESPACE}"
fi

# 10. Verify user does NOT have write permissions
check_step "User CANNOT create pods in ${NAMESPACE} (correct)"
if ! kubectl auth can-i create pods -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User should NOT be able to create pods (too many permissions granted)"
fi

check_step "User CANNOT delete deployments in ${NAMESPACE} (correct)"
if ! kubectl auth can-i delete deployments -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User should NOT be able to delete deployments (too many permissions granted)"
fi

check_step "User CANNOT update pods in ${NAMESPACE} (correct)"
if ! kubectl auth can-i update pods -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User should NOT be able to update pods (too many permissions granted)"
fi

# 11. Check exported kubeconfig file
check_step "Exported kubeconfig file exists"
if [[ -f "${WORKDIR}/siddhi-kubeconfig.yaml" ]]; then
  # Verify it contains the user
  if grep -q "${USER}" "${WORKDIR}/siddhi-kubeconfig.yaml"; then
    # Verify it contains the context
    if grep -q "${CONTEXT}" "${WORKDIR}/siddhi-kubeconfig.yaml"; then
      # Verify it's a valid kubeconfig by testing it
      if kubectl --kubeconfig="${WORKDIR}/siddhi-kubeconfig.yaml" config view &>/dev/null; then
        pass_step
      else
        fail_step "Exported kubeconfig is not valid YAML"
      fi
    else
      fail_step "Exported kubeconfig does not contain context ${CONTEXT}"
    fi
  else
    fail_step "Exported kubeconfig does not contain user ${USER}"
  fi
else
  fail_step "Exported kubeconfig file not found at ${WORKDIR}/siddhi-kubeconfig.yaml"
fi

# 12. Test exported kubeconfig functionality
check_step "Exported kubeconfig can authenticate and list pods"
if kubectl --kubeconfig="${WORKDIR}/siddhi-kubeconfig.yaml" get pods -n "${NAMESPACE}" &>/dev/null; then
  pass_step
else
  fail_step "Cannot authenticate or list pods using exported kubeconfig"
fi

# Print summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
if [[ $PASSED -eq $TOTAL ]]; then
  echo "🎉 VERIFICATION PASSED! All checks successful!"
  echo ""
  echo "📊 Summary:"
  echo "   ✅ Certificate-based authentication configured correctly"
  echo "   ✅ Kubeconfig user and context created"
  echo "   ✅ RBAC Role and RoleBinding implemented"
  echo "   ✅ Read-only permissions verified (get, list, watch)"
  echo "   ✅ Write permissions correctly restricted"
  echo "   ✅ Exported kubeconfig functional"
  echo ""
  echo "🎓 Excellent work! You've successfully completed a comprehensive"
  echo "   user onboarding workflow covering:"
  echo "   • X.509 certificate generation and signing"
  echo "   • Kubeconfig management"
  echo "   • RBAC configuration"
  echo "   • Permission verification"
  echo ""
  echo "🚀 Ready for the CKA exam! This scenario covers multiple"
  echo "   critical security and authentication topics."
  echo "═══════════════════════════════════════════════════════════════"
  exit 0
else
  echo "❌ VERIFICATION FAILED!"
  echo ""
  echo "📊 Results: $PASSED/$TOTAL checks passed"
  echo ""
  echo "💡 Review the errors above and fix the issues."
  echo "   Refer to the solution in step1.md if needed."
  echo "═══════════════════════════════════════════════════════════════"
  exit 1
fi
