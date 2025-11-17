#!/bin/bash
set -euo pipefail

NS="isro-jaxa"
DEPLOYMENT="isro-jaxa-collab-deployment"
HPA_NAME="isro-jaxa-collab-deployment"
MIN_REPLICAS=1
MAX_REPLICAS=5
TARGET_CPU=50
AUDIT_FILE="/isro-jaxa/space-details.txt"

echo "🔍 Verifying HPA configuration and resource audit..."

# Check namespace
if ! kubectl get ns "${NS}" &>/dev/null; then
  echo "❌ Namespace '${NS}' not found"
  exit 1
fi

# Check Deployment existence
if ! kubectl get deployment "${DEPLOYMENT}" -n "${NS}" &>/dev/null; then
  echo "❌ Deployment '${DEPLOYMENT}' not found in namespace '${NS}'"
  exit 1
fi

# Check HPA existence
if ! kubectl get hpa "${HPA_NAME}" -n "${NS}" &>/dev/null; then
  echo "❌ HPA '${HPA_NAME}' not found in namespace '${NS}'"
  echo "💡 Hint: Create HPA using: kubectl autoscale deployment ${DEPLOYMENT} -n ${NS} --cpu-percent=${TARGET_CPU} --min=${MIN_REPLICAS} --max=${MAX_REPLICAS}"
  exit 1
else
  echo "✅ HPA '${HPA_NAME}' exists"
fi

# Verify minReplicas
ACTUAL_MIN=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.minReplicas}')
if [[ "${ACTUAL_MIN}" != "${MIN_REPLICAS}" ]]; then
  echo "❌ Incorrect minReplicas: ${ACTUAL_MIN} (expected: ${MIN_REPLICAS})"
  exit 1
else
  echo "✅ minReplicas verified: ${MIN_REPLICAS}"
fi

# Verify maxReplicas
ACTUAL_MAX=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.maxReplicas}')
if [[ "${ACTUAL_MAX}" != "${MAX_REPLICAS}" ]]; then
  echo "❌ Incorrect maxReplicas: ${ACTUAL_MAX} (expected: ${MAX_REPLICAS})"
  exit 1
else
  echo "✅ maxReplicas verified: ${MAX_REPLICAS}"
fi

# Verify target CPU utilization
ACTUAL_CPU=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.metrics[?(@.type=="Resource")].resource.target.averageUtilization}' 2>/dev/null || true)
if [[ -z "${ACTUAL_CPU}" ]]; then
  echo "⚠️  Could not read target CPU from HPA spec (metrics not set or different format). Skipping CPU target check."
else
  if [[ "${ACTUAL_CPU}" != "${TARGET_CPU}" ]]; then
    echo "❌ Incorrect target CPU utilization: ${ACTUAL_CPU}% (expected: ${TARGET_CPU}%)"
    exit 1
  else
    echo "✅ Target CPU utilization verified: ${TARGET_CPU}%"
  fi
fi

# Verify scaleTargetRef points to correct deployment
TARGET_NAME=$(kubectl get hpa "${HPA_NAME}" -n "${NS}" -o jsonpath='{.spec.scaleTargetRef.name}')
if [[ "${TARGET_NAME}" != "${DEPLOYMENT}" ]]; then
  echo "❌ HPA targets wrong deployment: ${TARGET_NAME} (expected: ${DEPLOYMENT})"
  exit 1
else
  echo "✅ HPA targets correct deployment: ${DEPLOYMENT}"
fi

# Check if audit file exists
if [[ ! -f "${AUDIT_FILE}" ]]; then
  echo "❌ Resource audit file not found: ${AUDIT_FILE}"
  echo "💡 Hint: Run the exact command and save output to the file:"
  echo "   k top po -n ${NS} --sum=true > ${AUDIT_FILE}"
  echo "   (or: kubectl top pods -n ${NS} --sum=true > ${AUDIT_FILE})"
  exit 1
else
  echo "✅ Resource audit file exists: ${AUDIT_FILE}"
fi

# Extract the last non-empty line from the file (expected to contain TOTAL)
LAST_LINE=$(awk 'NF{line=$0} END{print line}' "${AUDIT_FILE}" || true)

if [[ -z "${LAST_LINE}" ]]; then
  echo "❌ Audit file '${AUDIT_FILE}' is empty or malformed."
  echo "   Current content:"
  sed -n '1,200p' "${AUDIT_FILE}" || true
  exit 1
fi

# Try to extract CPU and Memory from the last line.
# Typical formats:
#   TOTAL   250m   512Mi
# or
#   total   250m   512Mi
# We fallback to taking the last two fields if the first field isn't TOTAL.
CPU_FIELD=$(echo "${LAST_LINE}" | awk '{ if (tolower($1) ~ /^total|^_/ ) { print $(NF-1) } else if (tolower($1) == "total") { print $(NF-1) } else { print $(NF-1) } }')
MEM_FIELD=$(echo "${LAST_LINE}" | awk '{ print $NF }')

# If parsing failed, try alternate: last two fields
if [[ -z "${CPU_FIELD}" || -z "${MEM_FIELD}" ]]; then
  CPU_FIELD=$(echo "${LAST_LINE}" | awk '{print $(NF-1)}')
  MEM_FIELD=$(echo "${LAST_LINE}" | awk '{print $NF}')
fi

# Normalize units (expect CPU in 'm' and Memory in 'Mi'; accept other forms but strip non-digits)
CPU_VAL=$(echo "${CPU_FIELD}" | sed 's/[^0-9]*//g')
MEM_VAL=$(echo "${MEM_FIELD}" | sed 's/[^0-9]*//g')

if [[ -z "${CPU_VAL}" || -z "${MEM_VAL}" ]]; then
  echo "❌ Could not parse CPU/MEM values from audit file."
  echo "   Last line: ${LAST_LINE}"
  exit 1
fi

echo "✅ Parsed from file: CPU='${CPU_FIELD}' -> ${CPU_VAL}m ; MEM='${MEM_FIELD}' -> ${MEM_VAL}Mi"

# Verify numeric
if ! [[ "${CPU_VAL}" =~ ^[0-9]+$ ]]; then
  echo "❌ Total CPU value is not numeric: ${CPU_VAL}"
  exit 1
fi

if ! [[ "${MEM_VAL}" =~ ^[0-9]+$ ]]; then
  echo "❌ Total Memory value is not numeric: ${MEM_VAL}"
  exit 1
fi

TOTAL_CPU="${CPU_VAL}"
TOTAL_MEM="${MEM_VAL}"

# Sanity check against zero
if [[ "${TOTAL_CPU}" -eq 0 ]]; then
  echo "❌ Total CPU is 0m. This is likely incorrect."
  echo "   Recompute using: k top po -n ${NS} --sum=true > ${AUDIT_FILE}"
  exit 1
fi

if [[ "${TOTAL_MEM}" -eq 0 ]]; then
  echo "❌ Total Memory is 0Mi. This is likely incorrect."
  echo "   Recompute using: k top po -n ${NS} --sum=true > ${AUDIT_FILE}"
  exit 1
fi

echo "📊 Resource Audit Results (from file):"
echo "   Total CPU: ${TOTAL_CPU}m"
echo "   Total Memory: ${TOTAL_MEM}Mi"

# Compare with live kubectl top output (if available)
LIVE_LINE=$(kubectl top pods -n "${NS}" --sum=true 2>/dev/null | awk 'NF{line=$0} END{print line}' || true)
if [[ -n "${LIVE_LINE}" ]]; then
  LIVE_CPU_FIELD=$(echo "${LIVE_LINE}" | awk '{print $(NF-1)}')
  LIVE_MEM_FIELD=$(echo "${LIVE_LINE}" | awk '{print $NF}')
  LIVE_CPU_NUM=$(echo "${LIVE_CPU_FIELD}" | sed 's/[^0-9]*//g' || true)
  LIVE_MEM_NUM=$(echo "${LIVE_MEM_FIELD}" | sed 's/[^0-9]*//g' || true)

  if [[ -n "${LIVE_CPU_NUM}" && -n "${LIVE_MEM_NUM}" ]]; then
    CPU_DIFF=$(( TOTAL_CPU - LIVE_CPU_NUM ))
    CPU_DIFF=${CPU_DIFF#-}
    MEM_DIFF=$(( TOTAL_MEM - LIVE_MEM_NUM ))
    MEM_DIFF=${MEM_DIFF#-}

    CPU_THRESHOLD=$(( LIVE_CPU_NUM / 10 ))
    MEM_THRESHOLD=$(( LIVE_MEM_NUM / 10 ))
    [[ ${CPU_THRESHOLD} -eq 0 ]] && CPU_THRESHOLD=5
    [[ ${MEM_THRESHOLD} -eq 0 ]] && MEM_THRESHOLD=5

    if [[ ${CPU_DIFF} -gt ${CPU_THRESHOLD} ]]; then
      echo "⚠️  Warning: File CPU (${TOTAL_CPU}m) differs from live metrics (${LIVE_CPU_FIELD}) by ${CPU_DIFF}m (threshold ${CPU_THRESHOLD}m)."
      echo "   File might be outdated; consider regenerating it."
    else
      echo "✅ CPU values match live metrics (within threshold)."
    fi

    if [[ ${MEM_DIFF} -gt ${MEM_THRESHOLD} ]]; then
      echo "⚠️  Warning: File Memory (${TOTAL_MEM}Mi) differs from live metrics (${LIVE_MEM_FIELD}) by ${MEM_DIFF}Mi (threshold ${MEM_THRESHOLD}Mi)."
      echo "   File might be outdated; consider regenerating it."
    else
      echo "✅ Memory values match live metrics (within threshold)."
    fi
  else
    echo "⚠️  Unable to parse live metrics for comparison. Skipping live comparison."
  fi
else
  echo "⚠️  Could not fetch live metrics (kubectl top pods -n ${NS} --sum=true). Skipping live comparison."
fi

# Show current HPA status
echo ""
echo "📈 Current HPA Status:"
kubectl get hpa "${HPA_NAME}" -n "${NS}" 2>/dev/null || echo "   HPA metrics not available yet"

echo ""
echo "🎉 Verification finished! HPA configured and resource audit file validated."
exit 0
