#!/bin/bash
set -euo pipefail

NS="nginx-cyperpunk"
PVC_NAME="nginx-pv-claim"
DEPLOY_NAME="nginx-scifi-portal"
PV_NAME="nginx-pv"

echo "🔍 Verifying PVC and Deployment configuration..."

# Check if PVC manifest exists
if [[ ! -f /src/nginx/nginx-pvc.yaml ]]; then
  echo "❌ PVC manifest not found at /src/nginx/nginx-pvc.yaml"
  echo "   Please create the PersistentVolumeClaim manifest file"
  exit 1
fi

echo "✅ PVC manifest file exists"

# Check if PVC exists
if ! kubectl get pvc "${PVC_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ PersistentVolumeClaim '${PVC_NAME}' not found in namespace '${NS}'"
  echo "   Did you apply the PVC manifest?"
  exit 1
fi

echo "✅ PersistentVolumeClaim '${PVC_NAME}' exists"

# Check PVC is bound
PVC_STATUS=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.status.phase}')
if [[ "${PVC_STATUS}" != "Bound" ]]; then
  echo "❌ PVC status is '${PVC_STATUS}', expected 'Bound'"
  echo "   Check if the PVC configuration matches the PV"
  kubectl get pvc "${PVC_NAME}" -n "${NS}"
  exit 1
fi

echo "✅ PVC is Bound to PV"

# Check if PVC is bound to correct PV
BOUND_PV=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.volumeName}')
if [[ "${BOUND_PV}" != "${PV_NAME}" ]]; then
  echo "❌ PVC is bound to '${BOUND_PV}', expected '${PV_NAME}'"
  exit 1
fi

echo "✅ PVC is bound to correct PV: ${PV_NAME}"

# Check storage class
STORAGE_CLASS=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.storageClassName}')
if [[ "${STORAGE_CLASS}" != "local-path" ]]; then
  echo "❌ PVC storageClassName is '${STORAGE_CLASS}', expected 'local-path'"
  exit 1
fi

echo "✅ Correct storageClassName: ${STORAGE_CLASS}"

# Check storage request
STORAGE_REQUEST=$(kubectl get pvc "${PVC_NAME}" -n "${NS}" -o jsonpath='{.spec.resources.requests.storage}')
if [[ "${STORAGE_REQUEST}" != "350Mi" ]]; then
  echo "❌ PVC storage request is '${STORAGE_REQUEST}', expected '350Mi'"
  exit 1
fi

echo "✅ Correct storage request: ${STORAGE_REQUEST}"

# Check if deployment exists
if ! kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOY_NAME}' not found in namespace '${NS}'"
  echo "   Did you apply the deployment manifest?"
  exit 1
fi

echo "✅ Deployment '${DEPLOY_NAME}' exists"

# Check if deployment has volumes configured
VOLUME_CHECK=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.volumes}')
if [[ -z "${VOLUME_CHECK}" || "${VOLUME_CHECK}" == "null" ]]; then
  echo "❌ Deployment does not have volumes configured"
  echo "   Please add the volume section to the deployment spec"
  exit 1
fi

echo "✅ Deployment has volumes configured"

# Check if the correct PVC is referenced
PVC_IN_DEPLOY=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}')
if [[ "${PVC_IN_DEPLOY}" != "${PVC_NAME}" ]]; then
  echo "❌ Deployment references PVC '${PVC_IN_DEPLOY}', expected '${PVC_NAME}'"
  exit 1
fi

echo "✅ Deployment references correct PVC: ${PVC_NAME}"

# Check volume name
VOLUME_NAME=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.volumes[?(@.persistentVolumeClaim)].name}')
if [[ "${VOLUME_NAME}" != "nginx-pv" ]]; then
  echo "❌ Volume name is '${VOLUME_NAME}', expected 'nginx-pv'"
  exit 1
fi

echo "✅ Correct volume name: ${VOLUME_NAME}"

# Check if volumeMounts are configured
VOLUME_MOUNTS=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts}')
if [[ -z "${VOLUME_MOUNTS}" || "${VOLUME_MOUNTS}" == "null" ]]; then
  echo "❌ Container does not have volumeMounts configured"
  echo "   Please add volumeMounts to the container spec"
  exit 1
fi

echo "✅ Container has volumeMounts configured"

# Check mount path
MOUNT_PATH=$(kubectl get deployment "${DEPLOY_NAME}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="nginx-pv")].mountPath}')
if [[ "${MOUNT_PATH}" != "/usr/share/nginx/html" ]]; then
  echo "❌ Volume mount path is '${MOUNT_PATH}', expected '/usr/share/nginx/html'"
  exit 1
fi

echo "✅ Correct mount path: ${MOUNT_PATH}"

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
if ! kubectl wait --for=condition=Ready pod -l app=nginx-scifi -n "${NS}" --timeout=90s 2>/dev/null; then
  echo "❌ Pods did not become ready in time"
  echo ""
  echo "Checking pod status:"
  kubectl get pods -n "${NS}" -l app=nginx-scifi
  echo ""
  echo "Pod events:"
  kubectl get events -n "${NS}" --sort-by='.lastTimestamp' | tail -10
  exit 1
fi

# Check pod count
POD_COUNT=$(kubectl get pods -n "${NS}" -l app=nginx-scifi --field-selector=status.phase=Running --no-headers | wc -l)
if [[ "${POD_COUNT}" -lt 3 ]]; then
  echo "❌ Expected 3 running pods, found ${POD_COUNT}"
  kubectl get pods -n "${NS}" -l app=nginx-scifi
  exit 1
fi

echo "✅ All 3 pods are running"

# Verify all pods are on node01 (due to local volume node affinity)
PODS_ON_NODE01=$(kubectl get pods -n "${NS}" -l app=nginx-scifi -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | grep -c "node01" || true)
if [[ "${PODS_ON_NODE01}" -ne 3 ]]; then
  echo "⚠️  Warning: Not all pods are on node01 (expected due to PV node affinity)"
  kubectl get pods -n "${NS}" -l app=nginx-scifi -o wide
fi

# Verify volume is actually mounted in a pod
POD_NAME=$(kubectl get pods -n "${NS}" -l app=nginx-scifi -o jsonpath='{.items[0].metadata.name}')
MOUNT_CHECK=$(kubectl exec -n "${NS}" "${POD_NAME}" -- df -h | grep "/usr/share/nginx/html" || echo "")
if [[ -z "${MOUNT_CHECK}" ]]; then
  echo "❌ Volume not mounted in pod at /usr/share/nginx/html"
  echo "   Checking mounts in pod:"
  kubectl exec -n "${NS}" "${POD_NAME}" -- df -h
  exit 1
fi

echo "✅ Volume successfully mounted in pods"

# Check service
if kubectl get svc nginx-scifi-portal-service -n "${NS}" &>/dev/null; then
  echo "✅ Service 'nginx-scifi-portal-service' is deployed"
  SVC_NODEPORT=$(kubectl get svc nginx-scifi-portal-service -n "${NS}" -o jsonpath='{.spec.ports[0].nodePort}')
  echo "✅ Service exposed on NodePort: ${SVC_NODEPORT}"
fi

echo ""
echo "🎉 Verification passed!"
echo "✅ PVC '${PVC_NAME}' created and bound to PV '${PV_NAME}'"
echo "✅ Deployment '${DEPLOY_NAME}' configured with volume mount"
echo "✅ All pods running with persistent storage mounted at /usr/share/nginx/html"
echo ""
echo "📋 Summary:"
kubectl get pv "${PV_NAME}"
kubectl get pvc -n "${NS}"
kubectl get pods -n "${NS}" -o wide

exit 0
