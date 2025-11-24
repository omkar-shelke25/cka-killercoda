#!/bin/bash
set -euo pipefail

USER="siddhi.shelke01"
NAMESPACE="game-dev"
ROLE="dev-access-role"
ROLEBINDING="siddhi-dev-binding"
CONTEXT="siddhi-mecha-dev"
CLUSTER="kubernetes"
CSR_NAME="siddhi"
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

# 1. Check private key exists and has correct size
check_step "Private key file exists and is 4096-bit RSA"
if [[ -f "${WORKDIR}/siddhi.shelke01.key" ]]; then
  if openssl rsa -in "${WORKDIR}/siddhi.shelke01.key" -check -noout &>/dev/null; then
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

# 2. Check CSR file exists and has correct subject
check_step "CSR file exists with correct subject (CN and O)"
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

# 3. Check Kubernetes CSR resource was created and approved
check_step "Kubernetes CertificateSigningRequest '${CSR_NAME}' exists and is approved"
if kubectl get csr "${CSR_NAME}" &>/dev/null; then
  CSR_CONDITION=$(kubectl get csr "${CSR_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Approved")].status}')
  if [[ "$CSR_CONDITION" == "True" ]]; then
    pass_step
  else
    fail_step "CSR exists but is not approved. Run: kubectl certificate approve ${CSR_NAME}"
  fi
else
  fail_step "Kubernetes CSR '${CSR_NAME}' not found. Create and apply CertificateSigningRequest resource."
fi

# 4. Check signed certificate exists and is valid
check_step "Signed certificate exists and is valid"
if [[ -f "${WORKDIR}/siddhi.shelke01.crt" ]]; then
  # Verify certificate is valid
  if openssl x509 -in "${WORKDIR}/siddhi.shelke01.crt" -noout -text &>/dev/null; then
    # Check certificate subject
    CERT_SUBJECT=$(openssl x509 -in "${WORKDIR}/siddhi.shelke01.crt" -noout -subject 2>/dev/null)
    if echo "$CERT_SUBJECT" | grep -q "CN.*=.*siddhi.shelke01" && echo "$CERT_SUBJECT" | grep -q "O.*=.*gameforge-studios"; then
      pass_step
    else
      fail_step "Certificate subject incorrect. Expected CN=siddhi.shelke01, O=gameforge-studios"
    fi
  else
    fail_step "Certificate file is not valid"
  fi
else
  fail_step "Certificate file not found at ${WORKDIR}/siddhi.shelke01.crt"
fi

# 5. Check user exists in kubeconfig with embedded certificates
check_step "User '${USER}' exists in kubeconfig with embedded certificates"
if kubectl config get-users | grep -q "^${USER}$"; then
  # Verify user has embedded certificate data (not file paths)
  USER_CERT_DATA=$(kubectl config view --raw -o jsonpath="{.users[?(@.name=='${USER}')].user.client-certificate-data}")
  USER_KEY_DATA=$(kubectl config view --raw -o jsonpath="{.users[?(@.name=='${USER}')].user.client-key-data}")
  
  if [[ -n "$USER_CERT_DATA" ]] && [[ -n "$USER_KEY_DATA" ]]; then
    pass_step
  else
    fail_step "User exists but certificates are not embedded. Use --embed-certs=true"
  fi
else
  fail_step "User '${USER}' not found in kubeconfig"
fi

# 6. Check context exists and references correct cluster
check_step "Context '${CONTEXT}' exists and references cluster '${CLUSTER}'"
if kubectl config get-contexts "${CONTEXT}" &>/dev/null; then
  CONTEXT_CLUSTER=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CONTEXT}')].context.cluster}")
  CONTEXT_USER=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CONTEXT}')].context.user}")
  CONTEXT_NAMESPACE=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CONTEXT}')].context.namespace}")
  
  if [[ "$CONTEXT_CLUSTER" == "$CLUSTER" ]] && [[ "$CONTEXT_USER" == "$USER" ]] && [[ "$CONTEXT_NAMESPACE" == "$NAMESPACE" ]]; then
    pass_step
  else
    fail_step "Context configuration incorrect. Expected cluster=${CLUSTER}, user=${USER}, namespace=${NAMESPACE}. Got cluster=${CONTEXT_CLUSTER}, user=${CONTEXT_USER}, namespace=${CONTEXT_NAMESPACE}"
  fi
else
  fail_step "Context '${CONTEXT}' not found"
fi

# 7. Check namespace exists
check_step "Namespace '${NAMESPACE}' exists"
if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  pass_step
else
  fail_step "Namespace '${NAMESPACE}' not found"
fi

# 8. Check Role exists with correct permissions
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

# 9. Check RoleBinding exists and binds correctly
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

# 10. Verify user has correct read permissions
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

check_step "User has permission to get deployments in ${NAMESPACE}"
if kubectl auth can-i get deployments -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User cannot get deployments in namespace ${NAMESPACE}"
fi

# 11. Verify user does NOT have write permissions
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

check_step "User CANNOT patch deployments in ${NAMESPACE} (correct)"
if ! kubectl auth can-i patch deployments -n "${NAMESPACE}" --as="${USER}" &>/dev/null; then
  pass_step
else
  fail_step "User should NOT be able to patch deployments (too many permissions granted)"
fi

# 12. Check exported kubeconfig file
check_step "Exported kubeconfig file exists"
if [[ -f "${WORKDIR}/siddhi-kubeconfig.yaml" ]]; then
  # Verify it contains the user
  if grep -q "${USER}" "${WORKDIR}/siddhi-kubeconfig.yaml"; then
    # Verify it contains the context
    if grep -q "${CONTEXT}" "${WORKDIR}/siddhi-kubeconfig.yaml"; then
      # Verify it references correct cluster name
      if grep -q "cluster: ${CLUSTER}" "${WORKDIR}/siddhi-kubeconfig.yaml"; then
        # Verify it's a valid kubeconfig
        if kubectl --kubeconfig="${WORKDIR}/siddhi-kubeconfig.yaml" config view &>/dev/null; then
          pass_step
        else
          fail_step "Exported kubeconfig is not valid YAML"
        fi
      else
        fail_step "Exported kubeconfig does not reference cluster '${CLUSTER}'"
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

# 13. Verify exported kubeconfig has embedded certificates
check_step "Exported kubeconfig has embedded certificate data"
if [[ -f "${WORKDIR}/siddhi-kubeconfig.yaml" ]]; then
  if grep -q "client-certificate-data:" "${WORKDIR}/siddhi-kubeconfig.yaml" && \
     grep -q "client-key-data:" "${WORKDIR}/siddhi-kubeconfig.yaml"; then
    pass_step
  else
    fail_step "Exported kubeconfig does not have embedded certificates. Use --embed-certs=true"
  fi
else
  fail_step "Cannot check - exported kubeconfig file not found"
fi

# 14. Test exported kubeconfig functionality
check_step "Exported kubeconfig can authenticate and list pods"
if kubectl --kubeconfig="${WORKDIR}/siddhi-kubeconfig.yaml" get pods -n "${NAMESPACE}" &>/dev/null; then
  pass_step
else
  fail_step "Cannot authenticate or list pods using exported kubeconfig"
fi

# 15. Test exported kubeconfig cannot create pods
check_step "Exported kubeconfig correctly restricted (cannot create pods)"
if ! kubectl --kubeconfig="${WORKDIR}/siddhi-kubeconfig.yaml" auth can-i create pods -n "${NAMESPACE}" 2>/dev/null | grep -q "yes"; then
  pass_step
else
  fail_step "Exported kubeconfig has too many permissions (can create pods)"
fi

# Print summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
if [[ $PASSED -eq $TOTAL ]]; then
  echo "🎉 VERIFICATION PASSED! All checks successful!"
  echo ""
  echo "📊 Summary:"
  echo "   ✅ Private key (4096-bit RSA) generated"
  echo "   ✅ CSR created with correct subject (CN and O)"
  echo "   ✅ Kubernetes CSR resource created and approved"
  echo "   ✅ Certificate extracted from approved CSR"
  echo "   ✅ Kubeconfig user configured with embedded certificates"
  echo "   ✅ Context created referencing correct cluster '${CLUSTER}'"
  echo "   ✅ RBAC Role and RoleBinding implemented"
  echo "   ✅ Read-only permissions verified (get, list, watch)"
  echo "   ✅ Write permissions correctly restricted"
  echo "   ✅ Exported kubeconfig functional with embedded certs"
  echo ""
  echo "🎓 Excellent work! You've successfully completed:"
  echo "   • Kubernetes CSR API workflow (certificates.k8s.io/v1)"
  echo "   • Certificate approval process"
  echo "   • Kubeconfig management with embedded certificates"
  echo "   • RBAC configuration (Role and RoleBinding)"
  echo "   • Permission verification and testing"
  echo ""
  echo "🔐 Key Achievement: Used Kubernetes-native CSR API instead of"
  echo "   manual OpenSSL signing - the recommended CKA approach!"
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
  echo "   Common mistakes:"
  echo "   • Not using Kubernetes CSR API (certificates.k8s.io/v1)"
  echo "   • Forgetting to approve the CSR with 'kubectl certificate approve'"
  echo "   • Using wrong cluster name (should be 'kubernetes')"
  echo "   • Not embedding certificates (missing --embed-certs=true)"
  echo ""
  echo "   Refer to the solution in step1.md if needed."
  echo "═══════════════════════════════════════════════════════════════"
  exit 1
fi
