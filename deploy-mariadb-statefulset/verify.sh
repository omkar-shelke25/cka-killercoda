#!/bin/bash
set -euo pipefail

NS="database"
SERVICE_NAME="mariadb"
STATEFULSET_NAME="mariadb"
REPLICAS=3
IMAGE="mariadb:10.6"
STORAGE_CLASS="local-path"
STORAGE_SIZE="250Mi"
ROOT_PASSWORD="rootpass"
PVC_NAME="mariadb-data"

echo "🔍 Verifying MariaDB StatefulSet deployment..."

# Check namespace
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  echo "💡 Hint: Create it using: kubectl create namespace ${NS}"
  exit 1
fi
echo "✅ Namespace '${NS}' exists"

# Check Service existence
if ! kubectl get service "${SERVICE_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ Service '${SERVICE_NAME}' not found in namespace '${NS}'"
  echo "💡 Hint: Create a headless service with clusterIP: None"
  exit 1
fi
echo "✅ Service '${SERVICE_NAME}' exists"

# Verify Service is headless
CLUSTER_IP=$(kubectl get service "${SERVICE_NAME}" -n "${NS}" -o jsonpath='{.spec.clusterIP}')
if [[ "${CLUSTER_IP}" != "None" ]]; then
  echo "❌ Service '${SERVICE_NAME}' is not headless (clusterIP should be 'None', found: '${CLUSTER_IP}')"
  exit 1
fi
echo "✅ Service '${SERVICE_NAME}' is headless (clusterIP: None)"

# Verify Service selector
SERVICE_SELECTOR=$(kubectl get service "${SERVICE_NAME}" -n "${NS}" -o jsonpath='{.spec.selector.app}')
if [[ "${SERVICE_SELECTOR}" != "mariadb" ]]; then
  echo "❌ Service selector incorrect: app=${SERVICE_SELECTOR} (expected: app=mariadb)"
  exit 1
fi
echo "✅ Service selector verified: app=mariadb"

# Verify Service port
SERVICE_PORT=$(kubectl get service "${SERVICE_NAME}" -n "${NS}" -o jsonpath='{.spec.ports[0].port}')
if [[ "${SERVICE_PORT}" != "3306" ]]; then
  echo "❌ Service port incorrect: ${SERVICE_PORT} (expected: 3306)"
  exit 1
fi
echo "✅ Service port verified: 3306"

# Check StatefulSet existence
if ! kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ StatefulSet '${STATEFULSET_NAME}' not found in namespace '${NS}'"
  echo "💡 Hint: Create a StatefulSet with 3 replicas using mariadb:10.6 image"
  exit 1
fi
echo "✅ StatefulSet '${STATEFULSET_NAME}' exists"

# Verify replicas
ACTUAL_REPLICAS=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.replicas}')
if [[ "${ACTUAL_REPLICAS}" != "${REPLICAS}" ]]; then
  echo "❌ Incorrect replica count: ${ACTUAL_REPLICAS} (expected: ${REPLICAS})"
  exit 1
fi
echo "✅ Replica count verified: ${REPLICAS}"

# Verify image
ACTUAL_IMAGE=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].image}')
if [[ "${ACTUAL_IMAGE}" != "${IMAGE}" ]]; then
  echo "❌ Incorrect image: ${ACTUAL_IMAGE} (expected: ${IMAGE})"
  exit 1
fi
echo "✅ Image verified: ${IMAGE}"

# Verify serviceName in StatefulSet
ACTUAL_SERVICE=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.serviceName}')
if [[ "${ACTUAL_SERVICE}" != "${SERVICE_NAME}" ]]; then
  echo "❌ StatefulSet serviceName incorrect: ${ACTUAL_SERVICE} (expected: ${SERVICE_NAME})"
  exit 1
fi
echo "✅ StatefulSet serviceName verified: ${SERVICE_NAME}"

# Verify environment variable
ACTUAL_ENV=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MARIADB_ROOT_PASSWORD")].value}')
if [[ "${ACTUAL_ENV}" != "${ROOT_PASSWORD}" ]]; then
  echo "❌ MARIADB_ROOT_PASSWORD incorrect or not set (expected: ${ROOT_PASSWORD})"
  exit 1
fi
echo "✅ MARIADB_ROOT_PASSWORD verified: ${ROOT_PASSWORD}"

# Verify volumeClaimTemplates
VCT_NAME=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' 2>/dev/null || echo "")
if [[ "${VCT_NAME}" != "${PVC_NAME}" ]]; then
  echo "❌ volumeClaimTemplate name incorrect: '${VCT_NAME}' (expected: '${PVC_NAME}')"
  exit 1
fi
echo "✅ volumeClaimTemplate name verified: ${PVC_NAME}"

# Verify storage class
VCT_STORAGE_CLASS=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}')
if [[ "${VCT_STORAGE_CLASS}" != "${STORAGE_CLASS}" ]]; then
  echo "❌ StorageClass incorrect: ${VCT_STORAGE_CLASS} (expected: ${STORAGE_CLASS})"
  exit 1
fi
echo "✅ StorageClass verified: ${STORAGE_CLASS}"

# Verify storage size
VCT_STORAGE_SIZE=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}')
if [[ "${VCT_STORAGE_SIZE}" != "${STORAGE_SIZE}" ]]; then
  echo "❌ Storage size incorrect: ${VCT_STORAGE_SIZE} (expected: ${STORAGE_SIZE})"
  exit 1
fi
echo "✅ Storage size verified: ${STORAGE_SIZE}"

# Verify access mode
VCT_ACCESS_MODE=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.accessModes[0]}')
if [[ "${VCT_ACCESS_MODE}" != "ReadWriteOnce" ]]; then
  echo "❌ Access mode incorrect: ${VCT_ACCESS_MODE} (expected: ReadWriteOnce)"
  exit 1
fi
echo "✅ Access mode verified: ReadWriteOnce"

# Verify volume mount path
MOUNT_PATH=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="mariadb-data")].mountPath}')
if [[ "${MOUNT_PATH}" != "/var/lib/mysql" ]]; then
  echo "❌ Volume mount path incorrect: ${MOUNT_PATH} (expected: /var/lib/mysql)"
  exit 1
fi
echo "✅ Volume mount path verified: /var/lib/mysql"

# Wait for all Pods to be ready (with timeout)
echo "⏳ Waiting for all ${REPLICAS} Pods to be ready..."
TIMEOUT=300
ELAPSED=0
while true; do
  READY_REPLICAS=$(kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  
  if [[ "${READY_REPLICAS}" == "${REPLICAS}" ]]; then
    echo "✅ All ${REPLICAS} Pods are ready"
    break
  fi
  
  if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
    echo "❌ Timeout waiting for Pods to be ready (${READY_REPLICAS}/${REPLICAS} ready after ${TIMEOUT}s)"
    echo "📋 Current Pod status:"
    kubectl get pods -n "${NS}" -l app=mariadb
    echo ""
    echo "📋 StatefulSet status:"
    kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}"
    exit 1
  fi
  
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

# Verify all PVCs are created and bound
echo "🔍 Verifying PersistentVolumeClaims..."
for i in $(seq 0 $((REPLICAS - 1))); do
  PVC="${PVC_NAME}-${STATEFULSET_NAME}-${i}"
  
  if ! kubectl get pvc "${PVC}" -n "${NS}" &>/dev/null; then
    echo "❌ PVC '${PVC}' not found"
    exit 1
  fi
  
  PVC_STATUS=$(kubectl get pvc "${PVC}" -n "${NS}" -o jsonpath='{.status.phase}')
  if [[ "${PVC_STATUS}" != "Bound" ]]; then
    echo "❌ PVC '${PVC}' is not bound (status: ${PVC_STATUS})"
    exit 1
  fi
  
  echo "✅ PVC '${PVC}' is bound"
done

# Verify Pod DNS names (basic check)
echo "🔍 Verifying Pod stable network identities..."
for i in $(seq 0 $((REPLICAS - 1))); do
  POD_NAME="${STATEFULSET_NAME}-${i}"
  
  if ! kubectl get pod "${POD_NAME}" -n "${NS}" &>/dev/null; then
    echo "❌ Pod '${POD_NAME}' not found"
    exit 1
  fi
  
  echo "✅ Pod '${POD_NAME}' exists with stable identity"
done

# Test MariaDB connectivity (optional but recommended)
echo "🔍 Testing MariaDB connectivity..."
TEST_RESULT=$(kubectl exec mariadb-0 -n "${NS}" -- mysql -uroot -p"${ROOT_PASSWORD}" -e "SELECT 1 AS test;" 2>/dev/null | grep -c "test" || echo "0")

if [[ "${TEST_RESULT}" -ge 1 ]]; then
  echo "✅ MariaDB is accessible and responding to queries"
else
  echo "⚠️  Warning: Could not verify MariaDB connectivity (might still be initializing)"
fi

# Display summary
echo ""
echo "📊 Deployment Summary:"
kubectl get statefulset "${STATEFULSET_NAME}" -n "${NS}"
echo ""
kubectl get pods -n "${NS}" -l app=mariadb
echo ""
kubectl get pvc -n "${NS}"
echo ""
kubectl get service "${SERVICE_NAME}" -n "${NS}"

echo ""
echo "🎉 Verification complete! MariaDB StatefulSet deployed successfully with persistent storage."
echo ""
echo "💡 DNS names for Pods:"
for i in $(seq 0 $((REPLICAS - 1))); do
  echo "   - ${STATEFULSET_NAME}-${i}.${SERVICE_NAME}.${NS}.svc.cluster.local"
done

exit 0
