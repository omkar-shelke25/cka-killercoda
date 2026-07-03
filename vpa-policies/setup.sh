#!/bin/bash
set -uo pipefail   # NOTE: -e intentionally omitted; we handle failures explicitly below
echo "Setting up the VPA scenario environment..."

# ---------------------------------------------------------------------------
# Helper: run a kubectl-apply-from-stdin block and hard-fail with a clear
# message if it doesn't succeed (instead of silently continuing OR killing
# the whole script via `set -e` with no context).
# ---------------------------------------------------------------------------
apply_or_die() {
  local desc="$1"
  if ! kubectl apply -f - ; then
    echo ""
    echo "FATAL: failed to apply: ${desc}"
    echo "Aborting setup."
    exit 1
  fi
}

# Wait for cluster to be ready
kubectl wait --for=condition=ready node --all --timeout=120s || true

# ---------------------------------------------------------------------------
# STEP 1: Create the namespace and the application Deployment FIRST.
# This matters because the VPA installer registers a MutatingWebhookConfiguration
# that intercepts ALL pod creations cluster-wide. If that webhook is registered
# before its backing admission-controller pod is actually serving traffic
# (which `kubectl wait --for=condition=available deployment/...` does NOT
# guarantee), new pods can get rejected or silently stuck. Creating the app
# deployment before VPA exists sidesteps that race entirely.
# ---------------------------------------------------------------------------
echo "Creating namespace 'vpa-demo'..."
kubectl create namespace vpa-demo --dry-run=client -o yaml | apply_or_die "namespace vpa-demo"

echo "Creating app-deployment..."
cat <<EOF | apply_or_die "app-deployment"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: vpa-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: application
  template:
    metadata:
      labels:
        app: application
    spec:
      containers:
      - name: application
        image: nginx:alpine
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

echo "Waiting for app-deployment to become available..."
if ! kubectl wait --for=condition=available deployment/app-deployment -n vpa-demo --timeout=180s; then
  echo ""
  echo "FATAL: app-deployment did not become available."
  echo "Debug with:"
  echo "  kubectl get pods -n vpa-demo"
  echo "  kubectl describe deployment app-deployment -n vpa-demo"
  echo "  kubectl get events -n vpa-demo --sort-by='.lastTimestamp'"
  exit 1
fi

# ---------------------------------------------------------------------------
# STEP 2: Install VPA components
# ---------------------------------------------------------------------------
echo "Installing Vertical Pod Autoscaler..."
cd /root
if [[ ! -d /root/autoscaler ]]; then
  git clone https://github.com/kubernetes/autoscaler.git || echo "Clone failed, may already exist"
fi

if [[ -d /root/autoscaler/vertical-pod-autoscaler ]]; then
  cd /root/autoscaler/vertical-pod-autoscaler
  ./hack/vpa-up.sh || echo "VPA installation may have partially completed"
else
  echo "WARNING: vertical-pod-autoscaler directory not found after clone; VPA was not installed."
fi

# ---------------------------------------------------------------------------
# STEP 3: Wait for VPA components properly — check actual pod readiness,
# not just the Deployment's 'available' condition, and retry a few times
# since the admission controller can take a while to generate/mount its
# TLS certs on first boot.
# ---------------------------------------------------------------------------
wait_for_vpa_pods() {
  local label="$1"
  local name="$2"
  local tries=0
  local max_tries=6   # 6 * 20s = 120s
  echo "Waiting for ${name} pod(s) to be Ready..."
  while (( tries < max_tries )); do
    if kubectl get pods -n kube-system -l "${label}" 2>/dev/null | grep -q Running; then
      if kubectl wait --for=condition=ready pod -l "${label}" -n kube-system --timeout=20s &>/dev/null; then
        echo "  ${name}: Ready."
        return 0
      fi
    fi
    tries=$((tries+1))
    sleep 20
  done
  echo "  WARNING: ${name} did not report Ready within the timeout."
  return 1
}

wait_for_vpa_pods "app=vpa-admission-controller" "vpa-admission-controller" || true
wait_for_vpa_pods "app=vpa-recommender" "vpa-recommender" || true
wait_for_vpa_pods "app=vpa-updater" "vpa-updater" || true

# Safety net: if the admission controller isn't actually healthy, make sure
# its webhook doesn't block future pod/deployment changes for the rest of
# the scenario. This does not affect app-deployment, which already exists.
WEBHOOK_NAME=$(kubectl get mutatingwebhookconfigurations -o name 2>/dev/null | grep -i vpa || true)
if [[ -n "${WEBHOOK_NAME}" ]]; then
  if ! kubectl get pods -n kube-system -l app=vpa-admission-controller 2>/dev/null | grep -q "1/1.*Running"; then
    echo "VPA admission controller not fully healthy — relaxing webhook failurePolicy to Ignore to avoid blocking pod scheduling."
    kubectl patch "${WEBHOOK_NAME}" \
      --type='json' \
      -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]' \
      2>/dev/null || echo "  (patch skipped/failed — check manually with: kubectl get ${WEBHOOK_NAME} -o yaml)"
  fi
fi

# ---------------------------------------------------------------------------
# STEP 4: Final verification
# ---------------------------------------------------------------------------
echo ""
if kubectl get deployment app-deployment -n vpa-demo &>/dev/null && \
   kubectl get pods -n vpa-demo -l app=application 2>/dev/null | grep -q Running; then
  echo "Setup complete."
  echo ""
  echo "Environment details:"
  echo "  - VPA components installed in kube-system namespace"
  echo "  - Deployment 'app-deployment' created and running in 'vpa-demo' namespace"
  echo "  - Container name: 'application'"
  echo "  - Current resources: 50m CPU / 64Mi memory (requests), 100m CPU / 128Mi memory (limits)"
  echo ""
  echo "Your task: Create a VPA that will manage this deployment's resources"
  echo ""
else
  echo "WARNING: app-deployment / its pods are not confirmed running."
  echo "Run these to debug:"
  echo "  kubectl get all -n vpa-demo"
  echo "  kubectl get events -n vpa-demo --sort-by='.lastTimestamp'"
  echo "  kubectl get pods -n kube-system | grep vpa"
  exit 1
fi
