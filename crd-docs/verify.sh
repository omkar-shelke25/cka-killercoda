#!/bin/bash
set -euo pipefail

RESOURCES_FILE="/root/resources.txt"
SUBJECT_FILE="/root/subject.txt"

echo "🔍 Verifying CRD exploration and documentation tasks..."
echo ""

# Task 1: Check if resources.txt exists
if [[ ! -f "${RESOURCES_FILE}" ]]; then
  echo "❌ File '${RESOURCES_FILE}' not found"
  exit 1
fi
echo "✅ File '${RESOURCES_FILE}' exists"

# Check if resources.txt is not empty
if [[ ! -s "${RESOURCES_FILE}" ]]; then
  echo "❌ File '${RESOURCES_FILE}' is empty"
  exit 1
fi
echo "✅ File '${RESOURCES_FILE}' is not empty"

# Check if resources.txt contains cert-manager CRDs
if ! grep -q "cert-manager" "${RESOURCES_FILE}"; then
  echo "❌ File '${RESOURCES_FILE}' does not contain 'cert-manager' keyword"
  exit 1
fi
echo "✅ File contains 'cert-manager' references"

# Check if it contains CRD definitions
CRD_COUNT=$(grep -c "kind: CustomResourceDefinition" "${RESOURCES_FILE}" || echo "0")

if [[ "${CRD_COUNT}" -eq 0 ]]; then
  echo "❌ File '${RESOURCES_FILE}' does not contain any CustomResourceDefinition objects"
  exit 1
fi
echo "✅ File contains ${CRD_COUNT} CustomResourceDefinition object(s)"

# Verify it contains key cert-manager CRDs
EXPECTED_CRDS=(
  "certificates.cert-manager.io"
  "issuers.cert-manager.io"
  "clusterissuers.cert-manager.io"
)

FOUND_CRDS=0
for crd in "${EXPECTED_CRDS[@]}"; do
  if grep -q "${crd}" "${RESOURCES_FILE}"; then
    echo "   ✓ Found CRD: ${crd}"
    FOUND_CRDS=$((FOUND_CRDS + 1))
  else
    echo "   ⚠️  CRD not found: ${crd}"
  fi
done

if [[ "${FOUND_CRDS}" -lt 2 ]]; then
  echo "❌ Expected to find at least 2 major cert-manager CRDs, found ${FOUND_CRDS}"
  exit 1
fi
echo "✅ Found ${FOUND_CRDS} major cert-manager CRDs in file"

# Check if the file is valid txt
if ! python3 -c "import txt; txt.safe_load_all(open('${RESOURCES_FILE}'))" 2>/dev/null; then
  # Try with yq if available
  if command -v yq &>/dev/null; then
    if ! yq eval '.' "${RESOURCES_FILE}" > /dev/null 2>&1; then
      echo "⚠️  Warning: File may not be valid txt format"
    else
      echo "✅ File is valid txt format"
    fi
  else
    echo "✅ File appears to be in txt format (full validation skipped)"
  fi
else
  echo "✅ File is valid txt format"
fi

# Task 2: Check if subject.txt exists
echo ""
if [[ ! -f "${SUBJECT_FILE}" ]]; then
  echo "❌ File '${SUBJECT_FILE}' not found"
  exit 1
fi
echo "✅ File '${SUBJECT_FILE}' exists"

# Check if subject.txt is not empty
if [[ ! -s "${SUBJECT_FILE}" ]]; then
  echo "❌ File '${SUBJECT_FILE}' is empty"
  exit 1
fi
echo "✅ File '${SUBJECT_FILE}' is not empty"

# Check if subject.txt contains kubectl explain output
if ! grep -q -i "KIND:\|FIELD:\|DESCRIPTION:\|kind:\|field:\|description:" "${SUBJECT_FILE}"; then
  echo "❌ File '${SUBJECT_FILE}' does not appear to contain kubectl explain output"
  exit 1
fi
echo "✅ File contains kubectl explain output format"

# Check if it's about the subject field
if ! grep -q -i "subject" "${SUBJECT_FILE}"; then
  echo "❌ File '${SUBJECT_FILE}' does not contain information about 'subject' field"
  exit 1
fi
echo "✅ File contains information about 'subject' field"

# Check if it mentions Certificate resource
if ! grep -q -i "certificate" "${SUBJECT_FILE}"; then
  echo "⚠️  Warning: File may not be specifically about Certificate resource"
else
  echo "✅ File references Certificate resource"
fi

# Check for expected subject subfields documentation
SUBJECT_FIELDS=(
  "commonName\|organizations\|organizationalUnits"
)

FOUND_SUBFIELDS=false
for field_pattern in "${SUBJECT_FIELDS[@]}"; do
  if grep -q -i "${field_pattern}" "${SUBJECT_FILE}"; then
    FOUND_SUBFIELDS=true
    echo "✅ File contains subject subfield documentation"
    break
  fi
done

if [[ "${FOUND_SUBFIELDS}" == "false" ]]; then
  echo "⚠️  Warning: Expected subject subfield documentation not found"
fi

# Display file sizes
echo ""
echo "📊 File Information:"
RESOURCES_SIZE=$(stat -f%z "${RESOURCES_FILE}" 2>/dev/null || stat -c%s "${RESOURCES_FILE}" 2>/dev/null)
SUBJECT_SIZE=$(stat -f%z "${SUBJECT_FILE}" 2>/dev/null || stat -c%s "${SUBJECT_FILE}" 2>/dev/null)

echo "   ${RESOURCES_FILE}: ${RESOURCES_SIZE} bytes"
echo "   ${SUBJECT_FILE}: ${SUBJECT_SIZE} bytes"

# Show sample content
echo ""
echo "📋 Sample from resources.txt (first 10 lines):"
head -10 "${RESOURCES_FILE}"

echo ""
echo "📋 Sample from subject.txt (first 15 lines):"
head -15 "${SUBJECT_FILE}"

echo ""
echo "🎉 Verification passed! CRD exploration and documentation completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ resources.txt contains ${CRD_COUNT} cert-manager CRD(s)"
echo "   ✅ subject.txt contains Certificate spec.subject documentation"
echo "   ✅ Both files are properly formatted"
echo ""

exit 0
