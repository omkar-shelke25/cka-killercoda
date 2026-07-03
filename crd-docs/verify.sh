#!/bin/bash
set -euo pipefail

# Check Task 1: resources.txt
echo "Checking Task 1: /root/resources.txt"

if [[ ! -f /root/resources.txt ]]; then
  echo "FAIL: /root/resources.txt does not exist"
  echo "List cert-manager CRD names and save them to /root/resources.txt"
  exit 1
fi

# Check that the file contains cert-manager CRD names
if ! grep -q "cert-manager.io" /root/resources.txt; then
  echo "FAIL: /root/resources.txt does not contain cert-manager CRD names"
  echo "Expected to find CRD names like certificates.cert-manager.io"
  exit 1
fi

# Count how many cert-manager CRDs are listed
CRD_COUNT=$(grep -c "cert-manager.io" /root/resources.txt || true)
if [[ "${CRD_COUNT}" -lt 1 ]]; then
  echo "FAIL: /root/resources.txt should contain at least one cert-manager CRD name"
  exit 1
fi

echo "PASS: /root/resources.txt contains ${CRD_COUNT} cert-manager CRD name(s)"

# Check Task 2: subject.yaml
echo ""
echo "Checking Task 2: /root/subject.yaml"

if [[ ! -f /root/subject.yaml ]]; then
  echo "FAIL: /root/subject.yaml does not exist"
  echo "Run: kubectl explain certificate.spec.subject > /root/subject.yaml"
  exit 1
fi

if [[ ! -s /root/subject.yaml ]]; then
  echo "FAIL: /root/subject.yaml is empty"
  exit 1
fi

# Check that it contains subject-related documentation
if ! grep -qi "subject" /root/subject.yaml; then
  echo "FAIL: /root/subject.yaml does not contain subject field documentation"
  exit 1
fi

# Check that it looks like kubectl explain output (contains KIND or field descriptions)
if ! grep -qE "(KIND|FIELD|DESCRIPTION|Resource|spec)" /root/subject.yaml; then
  echo "FAIL: /root/subject.yaml does not appear to contain kubectl explain output"
  exit 1
fi

echo "PASS: /root/subject.yaml contains kubectl explain output for certificate.spec.subject"

# Show summary
echo ""
echo "Verification passed!"
echo ""
echo "Summary:"
echo "  PASS: /root/resources.txt contains cert-manager CRD names"
echo "  PASS: /root/subject.yaml contains certificate.spec.subject documentation"
echo ""
echo "Contents of /root/resources.txt:"
cat /root/resources.txt
echo ""
echo "Contents of /root/subject.yaml:"
cat /root/subject.yaml
echo ""

exit 0
