#!/bin/bash
set -euo pipefail

KUBECONFIG_FILE="/opt/course/1/kubeconfig"
CONTEXTS_FILE="/opt/course/1/contexts"
CURRENT_CONTEXT_FILE="/opt/course/1/current-context"
CERT_FILE="/opt/course/1/cert"
USER_NAME="account-0027"

echo "🔍 Verifying kubeconfig extraction tasks..."
echo ""

# Check kubeconfig file exists
if [[ ! -f "${KUBECONFIG_FILE}" ]]; then
  echo "❌ Kubeconfig file not found: ${KUBECONFIG_FILE}"
  exit 1
else
  echo "✅ Kubeconfig file exists: ${KUBECONFIG_FILE}"
fi

# Task 1: Verify contexts file
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Task 1: Checking contexts file..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ! -f "${CONTEXTS_FILE}" ]]; then
  echo "❌ Contexts file not found: ${CONTEXTS_FILE}"
  echo "   Expected: All context names from kubeconfig"
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config get-contexts --kubeconfig=${KUBECONFIG_FILE} -o name > ${CONTEXTS_FILE}"
  exit 1
fi

# Get expected contexts from kubeconfig
EXPECTED_CONTEXTS=$(kubectl config get-contexts --kubeconfig="${KUBECONFIG_FILE}" -o name 2>/dev/null | sort)
ACTUAL_CONTEXTS=$(cat "${CONTEXTS_FILE}" 2>/dev/null | sort)

if [[ -z "${ACTUAL_CONTEXTS}" ]]; then
  echo "❌ Contexts file is empty"
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config get-contexts --kubeconfig=${KUBECONFIG_FILE} -o name > ${CONTEXTS_FILE}"
  exit 1
fi

if [[ "${EXPECTED_CONTEXTS}" == "${ACTUAL_CONTEXTS}" ]]; then
  CONTEXT_COUNT=$(echo "${ACTUAL_CONTEXTS}" | wc -l)
  echo "✅ Contexts file correct (${CONTEXT_COUNT} contexts found)"
  echo ""
  echo "   Found contexts:"
  echo "${ACTUAL_CONTEXTS}" | sed 's/^/   ✓ /'
else
  echo "❌ Contexts file incorrect"
  echo ""
  echo "   Expected:"
  echo "${EXPECTED_CONTEXTS}" | sed 's/^/   - /'
  echo ""
  echo "   Got:"
  echo "${ACTUAL_CONTEXTS}" | sed 's/^/   - /'
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config get-contexts --kubeconfig=${KUBECONFIG_FILE} -o name > ${CONTEXTS_FILE}"
  exit 1
fi

# Task 2: Verify current-context file
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Task 2: Checking current-context file..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ! -f "${CURRENT_CONTEXT_FILE}" ]]; then
  echo "❌ Current-context file not found: ${CURRENT_CONTEXT_FILE}"
  echo "   Expected: The current context name from kubeconfig"
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config current-context --kubeconfig=${KUBECONFIG_FILE} > ${CURRENT_CONTEXT_FILE}"
  exit 1
fi

EXPECTED_CURRENT=$(kubectl config current-context --kubeconfig="${KUBECONFIG_FILE}" 2>/dev/null)
ACTUAL_CURRENT=$(cat "${CURRENT_CONTEXT_FILE}" 2>/dev/null | tr -d '\n' | xargs)

if [[ -z "${ACTUAL_CURRENT}" ]]; then
  echo "❌ Current-context file is empty"
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config current-context --kubeconfig=${KUBECONFIG_FILE} > ${CURRENT_CONTEXT_FILE}"
  exit 1
fi

if [[ "${EXPECTED_CURRENT}" == "${ACTUAL_CURRENT}" ]]; then
  echo "✅ Current context correct: ${ACTUAL_CURRENT}"
else
  echo "❌ Current context incorrect"
  echo "   Expected: ${EXPECTED_CURRENT}"
  echo "   Got:      ${ACTUAL_CURRENT}"
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config current-context --kubeconfig=${KUBECONFIG_FILE} > ${CURRENT_CONTEXT_FILE}"
  exit 1
fi

# Task 3: Verify certificate file
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Task 3: Checking certificate file..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ! -f "${CERT_FILE}" ]]; then
  echo "❌ Certificate file not found: ${CERT_FILE}"
  echo "   Expected: Decoded certificate for user '${USER_NAME}'"
  echo ""
  echo "💡 Solution:"
  echo "   kubectl config view --kubeconfig=${KUBECONFIG_FILE} --raw -o json | \\"
  echo "     jq -r '.users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"' | \\"
  echo "     base64 -d > ${CERT_FILE}"
  exit 1
fi

# Check if user account-0027 exists in kubeconfig
if ! grep -q "name: ${USER_NAME}" "${KUBECONFIG_FILE}"; then
  echo "⚠️  Warning: User '${USER_NAME}' not found in kubeconfig"
  echo "   Skipping certificate validation"
else
  # Get the expected certificate (base64 decoded)
  EXPECTED_CERT=$(kubectl config view --kubeconfig="${KUBECONFIG_FILE}" --raw -o json 2>/dev/null | \
    jq -r ".users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"" 2>/dev/null | \
    base64 -d 2>/dev/null || echo "")
  
  # If jq method fails, try grep/awk method
  if [[ -z "${EXPECTED_CERT}" ]]; then
    CERT_DATA=$(grep -A 10 "name: ${USER_NAME}" "${KUBECONFIG_FILE}" | \
      grep "client-certificate-data:" | \
      awk '{print $2}' || echo "")
    
    if [[ -n "${CERT_DATA}" ]]; then
      EXPECTED_CERT=$(echo "${CERT_DATA}" | base64 -d 2>/dev/null || echo "")
    fi
  fi
  
  ACTUAL_CERT=$(cat "${CERT_FILE}" 2>/dev/null)
  
  # Check if certificate was extracted
  if [[ -z "${ACTUAL_CERT}" ]]; then
    echo "❌ Certificate file is empty"
    echo ""
    echo "💡 Solution:"
    echo "   kubectl config view --kubeconfig=${KUBECONFIG_FILE} --raw -o json | \\"
    echo "     jq -r '.users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"' | \\"
    echo "     base64 -d > ${CERT_FILE}"
    exit 1
  fi
  
  # Verify it's a valid certificate format (must contain exactly one certificate)
  HAS_BEGIN=$(echo "${ACTUAL_CERT}" | grep -c "BEGIN CERTIFICATE" || true)
  HAS_END=$(echo "${ACTUAL_CERT}" | grep -c "END CERTIFICATE" || true)
  
  if [[ ${HAS_BEGIN} -eq 0 ]] || [[ ${HAS_END} -eq 0 ]]; then
    echo "❌ Certificate file does not contain a valid certificate"
    [[ ${HAS_BEGIN} -eq 0 ]] && echo "   Missing: -----BEGIN CERTIFICATE-----"
    [[ ${HAS_END} -eq 0 ]] && echo "   Missing: -----END CERTIFICATE-----"
    echo ""
    echo "💡 Solution:"
    echo "   kubectl config view --kubeconfig=${KUBECONFIG_FILE} --raw -o json | \\"
    echo "     jq -r '.users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"' | \\"
    echo "     base64 -d > ${CERT_FILE}"
    exit 1
  fi
  
  if [[ ${HAS_BEGIN} -ne 1 ]] || [[ ${HAS_END} -ne 1 ]]; then
    echo "❌ Certificate file should contain exactly ONE certificate for user '${USER_NAME}'"
    echo "   Found ${HAS_BEGIN} BEGIN marker(s) and ${HAS_END} END marker(s)"
    echo "   Expected: 1 BEGIN and 1 END marker"
    echo ""
    echo "💡 Solution:"
    echo "   kubectl config view --kubeconfig=${KUBECONFIG_FILE} --raw -o json | \\"
    echo "     jq -r '.users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"' | \\"
    echo "     base64 -d > ${CERT_FILE}"
    exit 1
  fi
  
  # Validate by re-extracting and comparing both the extraction and the file content
  echo "   Validating certificate extraction method..."
  
  # Extract certificate using the correct method
  VALIDATION_CERT=$(kubectl config view --kubeconfig="${KUBECONFIG_FILE}" --raw -o json 2>/dev/null | \
    jq -r ".users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"" 2>/dev/null | \
    base64 -d 2>/dev/null || echo "")
  
  # Read the actual file content
  ACTUAL_CERT_CONTENT=$(cat "${CERT_FILE}" 2>/dev/null)
  
  # Compare: extracted certificate == file content
  if [[ "${VALIDATION_CERT}" == "${ACTUAL_CERT_CONTENT}" ]]; then
    echo "✅ Certificate correctly extracted and decoded"
    echo "   ✓ Extraction method: kubectl config view --raw -o json | jq | base64 -d"
    echo "   ✓ File content matches: cat ${CERT_FILE}"
    echo "   ✓ Both outputs validated successfully"
  else
    echo "⚠️  Certificate extracted but content validation failed"
    echo ""
    
    # Check if the file contains a valid certificate format
    if openssl x509 -in "${CERT_FILE}" -text -noout &>/dev/null; then
      echo "   File contains a valid certificate, but may not match expected source"
      echo ""
      
      # Check if validation cert is also valid
      if echo "${VALIDATION_CERT}" | openssl x509 -text -noout &>/dev/null 2>&1; then
        echo "❌ Certificate mismatch detected:"
        echo "   - File content is valid but doesn't match kubeconfig"
        echo "   - Expected certificate for user '${USER_NAME}'"
      else
        echo "⚠️  Could not extract certificate from kubeconfig for validation"
      fi
    else
      echo "❌ Certificate is not valid or not properly decoded"
    fi
    
    echo ""
    echo "💡 Correct solution:"
    echo "   kubectl config view --kubeconfig=${KUBECONFIG_FILE} --raw -o json | \\"
    echo "     jq -r '.users[] | select(.name == \"${USER_NAME}\") | .user.\"client-certificate-data\"' | \\"
    echo "     base64 -d > ${CERT_FILE}"
    echo ""
    echo "   Verify with:"
    echo "   cat ${CERT_FILE}"
    exit 1
  fi
  
  # Show certificate details
  echo ""
  echo "📜 Certificate details:"
  CERT_SUBJECT=$(openssl x509 -in "${CERT_FILE}" -noout -subject 2>/dev/null | sed 's/subject=//')
  CERT_ISSUER=$(openssl x509 -in "${CERT_FILE}" -noout -issuer 2>/dev/null | sed 's/issuer=//')
  CERT_DATES=$(openssl x509 -in "${CERT_FILE}" -noout -dates 2>/dev/null)
  
  echo "   Subject: ${CERT_SUBJECT}"
  echo "   Issuer:  ${CERT_ISSUER}"
  echo "   ${CERT_DATES}" | sed 's/^/   /'
fi

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary of extracted files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   1. Contexts:        ${CONTEXTS_FILE} ($(wc -l < ${CONTEXTS_FILE}) lines)"
echo "   2. Current context: ${CURRENT_CONTEXT_FILE}"
echo "   3. Certificate:     ${CERT_FILE} ($(wc -l < ${CERT_FILE}) lines)"
echo ""
echo "🎉 All verification checks passed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
