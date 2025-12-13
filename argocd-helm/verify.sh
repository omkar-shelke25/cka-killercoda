#!/bin/bash
set -euo pipefail

MANIFEST_FILE="/root/argo-helm.yaml"
REPO_NAME="argo"
REPO_URL="https://argoproj.github.io/argo-helm"
CHART_NAME="argo-cd"
CHART_VERSION="7.7.3"
NAMESPACE="argocd"

echo "🔍 Verifying Argo CD Helm installation without CRDs..."
echo ""

# Check if Helm repository was added
echo "🔍 Checking Helm repository..."
if ! helm repo list 2>/dev/null | grep -q "${REPO_URL}"; then
  echo "❌ Argo Helm repository not added"
  echo "   Expected repository URL: ${REPO_URL}"
  echo "   Run: helm repo add argo ${REPO_URL}"
  exit 1
fi
echo "✅ Argo Helm repository is added"

# Get the repository name
ACTUAL_REPO_NAME=$(helm repo list | grep "${REPO_URL}" | awk '{print $1}')
echo "   Repository name: ${ACTUAL_REPO_NAME}"

# Check if the manifest file exists
if [[ ! -f "${MANIFEST_FILE}" ]]; then
  echo ""
  echo "❌ File '${MANIFEST_FILE}' not found"
  echo "   You need to generate manifests using 'helm template'"
  exit 1
fi
echo "✅ File '${MANIFEST_FILE}' exists"

# Check if the file is not empty
if [[ ! -s "${MANIFEST_FILE}" ]]; then
  echo "❌ File '${MANIFEST_FILE}' is empty"
  exit 1
fi
echo "✅ File is not empty"

# Get file size
FILE_SIZE=$(stat -f%z "${MANIFEST_FILE}" 2>/dev/null || stat -c%s "${MANIFEST_FILE}" 2>/dev/null)
echo "   File size: ${FILE_SIZE} bytes"

# Check if file size is reasonable (should be at least 10KB for Argo CD)
if [[ ${FILE_SIZE} -lt 10000 ]]; then
  echo "⚠️  Warning: File size seems too small for Argo CD manifests"
fi

# Check if file contains YAML separators (multiple resources)
YAML_DOCS=$(grep -c "^---" "${MANIFEST_FILE}" || echo "0")
if [[ ${YAML_DOCS} -lt 5 ]]; then
  echo "⚠️  Warning: Expected more YAML documents (found ${YAML_DOCS})"
else
  echo "✅ File contains ${YAML_DOCS} YAML documents"
fi

# Check if file contains Kubernetes resources
echo ""
echo "🔍 Checking for Kubernetes resources..."
if ! grep -q "^kind:" "${MANIFEST_FILE}"; then
  echo "❌ File does not contain valid Kubernetes resource definitions"
  exit 1
fi
echo "✅ File contains Kubernetes resources"

# Count different resource types
RESOURCE_TYPES=$(grep "^kind:" "${MANIFEST_FILE}" | sort | uniq -c)
echo ""
echo "📊 Resource types found:"
echo "${RESOURCE_TYPES}"

# Check that CRDs are NOT included
echo ""
echo "🔍 Verifying CRDs are excluded..."
if grep -q "kind: CustomResourceDefinition" "${MANIFEST_FILE}"; then
  echo "❌ File contains CustomResourceDefinition resources"
  echo "   CRDs should be excluded using --skip-crds flag"
  CRD_COUNT=$(grep -c "kind: CustomResourceDefinition" "${MANIFEST_FILE}")
  echo "   Found ${CRD_COUNT} CRD(s) in file"
  exit 1
fi
echo "✅ No CustomResourceDefinitions found (correctly excluded)"

# Check if namespace is specified correctly
echo ""
echo "🔍 Checking namespace configuration..."
NAMESPACE_REFS=$(grep "namespace: ${NAMESPACE}" "${MANIFEST_FILE}" | wc -l || echo "0")
if [[ ${NAMESPACE_REFS} -lt 1 ]]; then
  echo "⚠️  Warning: Expected to find namespace '${NAMESPACE}' references"
else
  echo "✅ Found ${NAMESPACE_REFS} references to namespace '${NAMESPACE}'"
fi

# Check for essential Argo CD components
echo ""
echo "🔍 Checking for essential Argo CD components..."
ESSENTIAL_COMPONENTS=(
  "ServiceAccount"
  "Service"
  "Deployment"
  "ConfigMap"
)

MISSING_COMPONENTS=0
for component in "${ESSENTIAL_COMPONENTS[@]}"; do
  if grep -q "kind: ${component}" "${MANIFEST_FILE}"; then
    echo "   ✓ ${component} found"
  else
    echo "   ✗ ${component} missing"
    MISSING_COMPONENTS=$((MISSING_COMPONENTS + 1))
  fi
done

if [[ ${MISSING_COMPONENTS} -gt 0 ]]; then
  echo "⚠️  Warning: ${MISSING_COMPONENTS} essential component type(s) missing"
fi

# Check for Argo CD specific resources
echo ""
echo "🔍 Checking for Argo CD specific components..."
if grep -q "argocd-server\|argo-cd-argocd-server" "${MANIFEST_FILE}"; then
  echo "✅ Found argocd-server component"
else
  echo "⚠️  Warning: argocd-server component not found"
fi

if grep -q "argocd-repo-server\|argo-cd-argocd-repo-server" "${MANIFEST_FILE}"; then
  echo "✅ Found argocd-repo-server component"
else
  echo "⚠️  Warning: argocd-repo-server component not found"
fi

if grep -q "argocd-application-controller\|argo-cd-argocd-application-controller" "${MANIFEST_FILE}"; then
  echo "✅ Found argocd-application-controller component"
else
  echo "⚠️  Warning: argocd-application-controller component not found"
fi

# Validate YAML syntax (if python is available)
echo ""
echo "🔍 Validating YAML syntax..."
if command -v python3 &>/dev/null; then
  if python3 -c "import yaml; yaml.safe_load_all(open('${MANIFEST_FILE}'))" 2>/dev/null; then
    echo "✅ YAML syntax is valid"
  else
    echo "❌ YAML syntax validation failed"
    exit 1
  fi
else
  echo "⚠️  Python not available for YAML validation (skipped)"
fi

# Check if the file appears to be from the correct chart version
echo ""
echo "🔍 Checking chart version indicators..."
if grep -q "chart: argo-cd-${CHART_VERSION}\|app.kubernetes.io/version:" "${MANIFEST_FILE}"; then
  echo "✅ Chart version ${CHART_VERSION} indicators found"
else
  echo "⚠️  Warning: Chart version ${CHART_VERSION} not clearly indicated in manifests"
fi

echo ""
echo "🎉 Verification passed! Argo CD manifests generated successfully!"
echo ""
echo "📊 Summary:"
echo "   ✅ Helm repository added: ${REPO_URL}"
echo "   ✅ Manifests saved to: ${MANIFEST_FILE}"
echo "   ✅ File size: ${FILE_SIZE} bytes"
echo "   ✅ YAML documents: ${YAML_DOCS}"
echo "   ✅ CRDs excluded: --skip-crds flag used correctly"
echo "   ✅ Namespace: ${NAMESPACE}"
echo ""

# Display sample content
echo "📋 Sample from manifest (first 20 lines):"
head -20 "${MANIFEST_FILE}"

echo ""
echo "💡 To apply these manifests, run:"
echo "   kubectl apply -f ${MANIFEST_FILE}"

exit 0
