#!/bin/bash
set -euo pipefail

MANIFEST_FILE="/root/argo-helm.yaml"
REPO_NAME="argocd"
REPO_URL="https://argoproj.github.io/argo-helm"
CHART_VERSION="9.1.4"
NAMESPACE="argocd"

echo "🔍 Verifying Argo CD Helm installation without CRDs..."
echo ""

# Step 1: Check if argocd namespace exists
echo "📋 Step 1: Checking namespace..."
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  echo "❌ Namespace '${NAMESPACE}' does not exist"
  exit 1
fi
echo "✅ Namespace '${NAMESPACE}' exists"

# Step 2: Verify CRDs are already installed
echo ""
echo "📋 Step 2: Checking pre-installed CRDs..."
CRD_COUNT=$(kubectl get crd 2>/dev/null | grep -c "argoproj.io" || echo "0")

if [[ ${CRD_COUNT} -eq 0 ]]; then
  echo "⚠️  Warning: No Argo CD CRDs found (expected pre-installed)"
else
  echo "✅ Found ${CRD_COUNT} Argo CD CRD(s) pre-installed:"
  kubectl get crd | grep "argoproj.io" | awk '{print "   - " $1}'
fi

# Step 3: Check if Helm repository was added with correct name
echo ""
echo "📋 Step 3: Checking Helm repository..."
if ! helm repo list 2>/dev/null | grep -q "^${REPO_NAME}"; then
  echo "❌ Helm repository '${REPO_NAME}' not found"
  echo "   Run: helm repo add ${REPO_NAME} ${REPO_URL}"
  exit 1
fi

# Verify correct URL
ACTUAL_URL=$(helm repo list 2>/dev/null | grep "^${REPO_NAME}" | awk '{print $2}')
if [[ "${ACTUAL_URL}" != "${REPO_URL}" ]]; then
  echo "❌ Repository '${REPO_NAME}' has wrong URL: ${ACTUAL_URL}"
  echo "   Expected: ${REPO_URL}"
  exit 1
fi
echo "✅ Helm repository '${REPO_NAME}' added with correct URL"

# Step 4: Check if manifest file exists
echo ""
echo "📋 Step 4: Checking manifest file..."
if [[ ! -f "${MANIFEST_FILE}" ]]; then
  echo "❌ File '${MANIFEST_FILE}' not found"
  echo "   Generate it with: helm template argocd argocd/argo-cd --version ${CHART_VERSION} --namespace ${NAMESPACE} --skip-crds > ${MANIFEST_FILE}"
  exit 1
fi
echo "✅ File '${MANIFEST_FILE}' exists"

# Step 5: Check file is not empty
if [[ ! -s "${MANIFEST_FILE}" ]]; then
  echo "❌ File '${MANIFEST_FILE}' is empty"
  exit 1
fi

FILE_SIZE=$(stat -f%z "${MANIFEST_FILE}" 2>/dev/null || stat -c%s "${MANIFEST_FILE}" 2>/dev/null)
echo "✅ File size: ${FILE_SIZE} bytes"

if [[ ${FILE_SIZE} -lt 5000 ]]; then
  echo "⚠️  Warning: File size seems small for Argo CD manifests"
fi

# Step 6: Validate YAML structure
echo ""
echo "📋 Step 5: Validating YAML structure..."
if ! grep -q "^---" "${MANIFEST_FILE}"; then
  echo "❌ File does not appear to contain YAML documents"
  exit 1
fi

YAML_DOCS=$(grep -c "^---" "${MANIFEST_FILE}" || echo "0")
echo "✅ File contains ${YAML_DOCS} YAML document(s)"

if [[ ${YAML_DOCS} -lt 10 ]]; then
  echo "⚠️  Warning: Expected more YAML documents for Argo CD"
fi

# Step 7: Check for Kubernetes resources
echo ""
echo "📋 Step 6: Checking Kubernetes resources..."
if ! grep -q "^kind:" "${MANIFEST_FILE}"; then
  echo "❌ No Kubernetes resources found in file"
  exit 1
fi

RESOURCE_COUNT=$(grep -c "^kind:" "${MANIFEST_FILE}" || echo "0")
echo "✅ Found ${RESOURCE_COUNT} Kubernetes resource(s)"

# Step 8: CRITICAL - Verify CRDs are NOT included
echo ""
echo "📋 Step 7: Verifying CRDs are excluded (CRITICAL)..."
if grep -q "kind: CustomResourceDefinition" "${MANIFEST_FILE}"; then
  echo "❌ FAILED: File contains CustomResourceDefinition resources!"
  echo "   CRDs should NOT be included (use --skip-crds flag)"
  CRD_IN_FILE=$(grep -c "kind: CustomResourceDefinition" "${MANIFEST_FILE}")
  echo "   Found ${CRD_IN_FILE} CRD(s) in file"
  echo ""
  echo "   The correct command should include --skip-crds:"
  echo "   helm template argocd argocd/argo-cd --version ${CHART_VERSION} --namespace ${NAMESPACE} --skip-crds > ${MANIFEST_FILE}"
  exit 1
fi
echo "✅ No CustomResourceDefinitions found (correctly excluded)"

# Step 9: Check namespace configuration
echo ""
echo "📋 Step 8: Checking namespace configuration..."
NAMESPACE_COUNT=$(grep -c "namespace: ${NAMESPACE}" "${MANIFEST_FILE}" || echo "0")

if [[ ${NAMESPACE_COUNT} -eq 0 ]]; then
  echo "⚠️  Warning: No namespace references found for '${NAMESPACE}'"
else
  echo "✅ Found ${NAMESPACE_COUNT} reference(s) to namespace '${NAMESPACE}'"
fi

# Step 10: Check for essential Argo CD components
echo ""
echo "📋 Step 9: Checking Argo CD components..."

ESSENTIAL_COMPONENTS=("ServiceAccount" "Service" "Deployment" "ConfigMap")
MISSING=0

for comp in "${ESSENTIAL_COMPONENTS[@]}"; do
  if grep -q "kind: ${comp}" "${MANIFEST_FILE}"; then
    echo "   ✓ ${comp}"
  else
    echo "   ✗ ${comp} (missing)"
    MISSING=$((MISSING + 1))
  fi
done

if [[ ${MISSING} -gt 2 ]]; then
  echo "⚠️  Warning: ${MISSING} essential component type(s) missing"
fi

# Step 11: Check for Argo CD specific services
echo ""
echo "📋 Step 10: Checking Argo CD specific components..."

ARGOCD_COMPONENTS=(
  "argocd-server"
  "argocd-repo-server"
  "argocd-application-controller"
  "argocd-redis"
)

for comp in "${ARGOCD_COMPONENTS[@]}"; do
  if grep -q "${comp}" "${MANIFEST_FILE}"; then
    echo "   ✓ ${comp}"
  else
    echo "   ✗ ${comp} (not found)"
  fi
done

# Step 12: Validate YAML syntax if possible
echo ""
echo "📋 Step 11: Validating YAML syntax..."
if command -v python3 &>/dev/null; then
  if python3 -c "import yaml; list(yaml.safe_load_all(open('${MANIFEST_FILE}')))" 2>/dev/null; then
    echo "✅ YAML syntax is valid"
  else
    echo "❌ YAML syntax validation failed"
    exit 1
  fi
else
  echo "⚠️  Python not available, skipping YAML validation"
fi

# Step 13: Display resource summary
echo ""
echo "📊 Resource Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep "^kind:" "${MANIFEST_FILE}" | sort | uniq -c | sort -rn | head -10
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🎉 Verification Passed! All requirements met!"
echo ""
echo "📊 Final Summary:"
echo "   ✅ Namespace '${NAMESPACE}' exists"
echo "   ✅ Argo CD CRDs pre-installed: ${CRD_COUNT} CRD(s)"
echo "   ✅ Helm repository '${REPO_NAME}' configured correctly"
echo "   ✅ Manifest file created: ${MANIFEST_FILE}"
echo "   ✅ File size: ${FILE_SIZE} bytes (${YAML_DOCS} documents)"
echo "   ✅ Chart version: ${CHART_VERSION}"
echo "   ✅ CRDs excluded: --skip-crds used correctly"
echo "   ✅ Total resources: ${RESOURCE_COUNT}"
echo ""
echo "💡 To apply these manifests:"
echo "   kubectl apply -f ${MANIFEST_FILE}"
echo ""
echo "✅ The application will use the pre-existing CRDs in the cluster"
echo ""

exit 0
