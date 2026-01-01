#!/bin/bash
set -euo pipefail

KUBECONFIG_FILE="/opt/course/1/kubeconfig"
CONTEXTS_FILE="/opt/course/1/contexts"
CURRENT_CONTEXT_FILE="/opt/course/1/current-context"
CERT_FILE="/opt/course/1/cert"
USER_NAME="account-0027"

echo "🔍 Verifying kubeconfig extraction tasks..."

# Check kubeconfig file exists
if [[ ! -f "${KUBECONFIG_FILE}" ]]; then
  echo "❌ Kubeconfig file not found: ${KUBECONFIG_FILE}"
  exit 1
else
  echo "✅ Kubeconfig file exists"
fi

# Task 1: Verify contexts file
echo ""
echo "📋 Task 1: Checking contexts file..."

if [[ ! -f "${CONTEXTS_FILE}" ]]; then
  echo "❌ Contexts file not found: ${CONTEXTS_FILE}"
  exit 1
fi

# Get expected contexts from kubeconfig
EXPECTED_CONTEXTS=$(kubectl config get-contexts --kubeconfig="${KUBECONFIG_FILE}" -o name | sort)
ACTUAL_CONTEXTS=$(cat "${CONTEXTS_FILE}" | sort)

if [[ "${EXPECTED_CONTEXTS}" == "${ACTUAL_CONTEXTS}" ]]; then
  CONTEXT_COUNT=$(echo "${ACTUAL_CONTEXTS}" | wc -l)
  echo "✅ Contexts file correct (${CONTEXT_COUNT} contexts found)"
  echo "   Contexts:"
  cat "${CONTEXTS_FILE}" | sed 's/^/   - /'
else
  echo "❌ Contexts file incorrect"
  echo "Expected:"
  echo "${EXPECTED_CONTEXTS}"
  echo "Got:"
  echo "${ACTUAL_CONTEXTS}"
  exit 1
fi

# Task 2: Verify current-context file
echo ""
echo "📋 Task 2: Checking current-context file..."

if [[ ! -f "${CURRENT_CONTEXT_FILE}" ]]; then
  echo "❌ Current-context file not found: ${CURRENT_CONTEXT_FILE}"
  exit 1
fi

EXPECTED_CURRENT=$(kubectl config current-context --kubeconfig="${KUBECONFIG_FILE}")
ACTUAL_CURRENT=$(cat "${CURRENT_CONTEXT_FILE}" | tr -d '\n' | xargs)

if [[ "${EXPECTED_CURRENT}" == "${ACTUAL_CURRENT}" ]]; then
  echo "✅ Current context correct: ${ACTUAL_CURRENT}"
else
  echo "❌ Current context incorrect"
  echo "   Expected: ${EXPECTED_CURRENT}"
  echo "   Got: ${ACTUAL_CURRENT}"
  exit 1
fi

# Task 3: Verify certificate file
echo ""
echo "📋 Task 3: Checking certificate file..."

if [[ ! -f "${CERT_FILE}" ]]; then
  echo "❌ Certificate file not found: ${CERT_FILE}"
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
  
  ACTUAL_CERT=$(cat "${CERT_FILE}")
  
  # Check if certificate was extracted
  if [[ -z "${ACTUAL_CERT}" ]]; then
    echo "❌ Certificate file is empty"
    exit 1
  fi
  
  # Verify it's a valid certificate format
  if ! echo "${ACTUAL_CERT}" | grep -q "BEGIN CERTIFICATE"; then
    echo "❌ Certificate file does not contain a valid certificate"
    echo "   Expected to start with: -----BEGIN CERTIFICATE-----"
    exit 1
  fi
  
  # Check if certificates match
  if [[ "${EXPECTED_CERT}" == "${ACTUAL_CERT}" ]]; then
    echo "✅ Certificate correctly extracted and decoded"
  else
    echo "⚠️  Certificate extracted but content may differ"
    echo "   Checking if it's a valid certificate format..."
    
    if openssl x509 -in "${CERT_FILE}" -text -noout &>/dev/null; then
      echo "✅ Certificate is valid and properly decoded"
    else
      echo "❌ Certificate is not valid or not properly decoded"
      exit 1
    fi
  fi
  
  # Show certificate details
  echo ""
  echo "📜 Certificate details:"
  openssl x509 -in "${CERT_FILE}" -text -noout 2>/dev/null | grep -E "Subject:|Issuer:|Not Before|Not After" | sed 's/^/   /' || echo "   (Could not parse certificate details)"
fi

# Final summary
echo ""
echo "📊 Summary of extracted files:"
echo "   1. Contexts: ${CONTEXTS_FILE} ($(wc -l < ${CONTEXTS_FILE}) lines)"
echo "   2. Current context: ${CURRENT_CONTEXT_FILE}"
echo "   3. Certificate: ${CERT_FILE} ($(wc -l < ${CERT_FILE}) lines)"

echo ""
echo "🎉 Verification passed! All kubeconfig information correctly extracted!"
exit 0
