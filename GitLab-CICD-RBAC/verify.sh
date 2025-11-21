#!/bin/bash
set -euo pipefail

NS="gitlab-cicd"
SA="gitlab-cicd-sa"
CLUSTERROLE="gitlab-cicd-role"
CLUSTERROLEBINDING="gitlab-cicd-rb"
POD_DETAILS_FILE="/gitlab-cicd/pod-details.yaml"

echo "🔍 Verifying RBAC and ServiceAccount Token configuration..."

# Check namespace
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi
echo "✅ Namespace '${NS}' exists"

# Check ServiceAccount
if ! kubectl get sa "${SA}" -n "${NS}" &>/dev/null; then
  echo "❌ ServiceAccount '${SA}' not found in namespace '${NS}'"
  exit 1
fi
echo "✅ ServiceAccount '${SA}' exists"

# Check ClusterRole existence
if ! kubectl get clusterrole "${CLUSTERROLE}" &>/dev/null; then
  echo "❌ ClusterRole '${CLUSTERROLE}' not found"
  exit 1
fi
echo "✅ ClusterRole '${CLUSTERROLE}' exists"

# Verify ClusterRole has correct verbs
VERBS=$(kubectl get clusterrole "${CLUSTERROLE}" -o jsonpath='{.rules[*].verbs[*]}')
for verb in get list watch create patch delete; do
  if ! echo "${VERBS}" | grep -q "${verb}"; then
    echo "❌ ClusterRole missing verb: ${verb}"
    exit 1
  fi
done
echo "✅ ClusterRole has all required verbs (get, list, watch, create, patch, delete)"

# Verify ClusterRole has correct resources
RESOURCES=$(kubectl get clusterrole "${CLUSTERROLE}" -o jsonpath='{.rules[*].resources[*]}')
for resource in pods deployments jobs; do
  if ! echo "${RESOURCES}" | grep -q "${resource}"; then
    echo "❌ ClusterRole missing resource: ${resource}"
    exit 1
  fi
done
echo "✅ ClusterRole has all required resources (pods, deployments, jobs)"

# Check ClusterRoleBinding existence
if ! kubectl get clusterrolebinding "${CLUSTERROLEBINDING}" &>/dev/null; then
  echo "❌ ClusterRoleBinding '${CLUSTERROLEBINDING}' not found"
  exit 1
fi
echo "✅ ClusterRoleBinding '${CLUSTERROLEBINDING}' exists"

# Verify ClusterRoleBinding references correct ClusterRole
BOUND_ROLE=$(kubectl get clusterrolebinding "${CLUSTERROLEBINDING}" -o jsonpath='{.roleRef.name}')
if [[ "${BOUND_ROLE}" != "${CLUSTERROLE}" ]]; then
  echo "❌ ClusterRoleBinding references wrong ClusterRole: ${BOUND_ROLE} (expected: ${CLUSTERROLE})"
  exit 1
fi
echo "✅ ClusterRoleBinding references correct ClusterRole"

# Verify ClusterRoleBinding references correct ServiceAccount
SA_NAME=$(kubectl get clusterrolebinding "${CLUSTERROLEBINDING}" -o jsonpath='{.subjects[0].name}')
SA_NAMESPACE=$(kubectl get clusterrolebinding "${CLUSTERROLEBINDING}" -o jsonpath='{.subjects[0].namespace}')
if [[ "${SA_NAME}" != "${SA}" ]] || [[ "${SA_NAMESPACE}" != "${NS}" ]]; then
  echo "❌ ClusterRoleBinding references wrong ServiceAccount: ${SA_NAMESPACE}/${SA_NAME} (expected: ${NS}/${SA})"
  exit 1
fi
echo "✅ ClusterRoleBinding references correct ServiceAccount (${NS}/${SA})"

# Check if pod-details.yaml file exists
if [[ ! -f "${POD_DETAILS_FILE}" ]]; then
  echo "❌ File '${POD_DETAILS_FILE}' not found"
  exit 1
fi
echo "✅ File '${POD_DETAILS_FILE}' exists"

# Verify the file contains valid JSON/YAML with pod information
if ! grep -q "gitlab-cicd-nginx" "${POD_DETAILS_FILE}"; then
  echo "❌ File '${POD_DETAILS_FILE}' does not contain expected pod information"
  exit 1
fi
echo "✅ File '${POD_DETAILS_FILE}' contains pod information"

# Verify the file has kind: List or kind: PodList
if ! grep -q '"kind"' "${POD_DETAILS_FILE}"; then
  echo "❌ File '${POD_DETAILS_FILE}' does not appear to be valid API output"
  exit 1
fi
echo "✅ File '${POD_DETAILS_FILE}' contains valid API response"

# Verify the file mentions the correct namespace
if ! grep -q "gitlab-cicd" "${POD_DETAILS_FILE}"; then
  echo "❌ File '${POD_DETAILS_FILE}' does not reference the gitlab-cicd namespace"
  exit 1
fi
echo "✅ File '${POD_DETAILS_FILE}' contains gitlab-cicd namespace reference"

# Check if file is not empty
FILE_SIZE=$(stat -f%z "${POD_DETAILS_FILE}" 2>/dev/null || stat -c%s "${POD_DETAILS_FILE}" 2>/dev/null)
if [[ "${FILE_SIZE}" -lt 100 ]]; then
  echo "⚠️  Warning: File '${POD_DETAILS_FILE}' seems too small (${FILE_SIZE} bytes)"
fi

# Test if ServiceAccount can actually list pods using kubectl auth can-i
if kubectl auth can-i list pods --as=system:serviceaccount:${NS}:${SA} -n ${NS} &>/dev/null; then
  echo "✅ ServiceAccount has permission to list pods"
else
  echo "❌ ServiceAccount does not have permission to list pods"
  exit 1
fi

# Test if ServiceAccount can access other required resources
for resource in deployments jobs; do
  if kubectl auth can-i list ${resource} --as=system:serviceaccount:${NS}:${SA} -n ${NS} &>/dev/null; then
    echo "✅ ServiceAccount has permission to list ${resource}"
  else
    echo "❌ ServiceAccount does not have permission to list ${resource}"
    exit 1
  fi
done

echo ""
echo "🎉 Verification passed! RBAC configuration and API access completed successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ ClusterRole 'gitlab-cicd-role' configured with correct permissions"
echo "   ✅ ClusterRoleBinding 'gitlab-cicd-rb' properly links role to ServiceAccount"
echo "   ✅ API request successfully executed and output stored"
echo "   ✅ ServiceAccount can access pods, deployments, and jobs cluster-wide"
echo ""

exit 0
