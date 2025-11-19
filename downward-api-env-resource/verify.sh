#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "   Verifying Downward API Configuration"
echo "========================================"
echo ""

# Check if pod exists
if ! kubectl get pod react-frontend-monitor -n react-frontend &>/dev/null; then
    echo -e "${RED}❌ FAIL: Pod react-frontend-monitor not found in namespace react-frontend${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Pod exists in react-frontend namespace"

# Check if pod is running
POD_STATUS=$(kubectl get pod react-frontend-monitor -n react-frontend -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${RED}❌ FAIL: Pod is not in Running state (current: $POD_STATUS)${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Pod is in Running state"

# Verify monitor-agent container has env variables defined
ENV_COUNT=$(kubectl get pod react-frontend-monitor -n react-frontend -o json | jq -r '.spec.containers[] | select(.name=="monitor-agent") | .env | length')

if [ "$ENV_COUNT" -lt 4 ]; then
    echo -e "${RED}❌ FAIL: monitor-agent container does not have 4 environment variables defined (found: $ENV_COUNT)${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} monitor-agent has environment variables defined"

# Check each required environment variable
declare -A required_envs=(
    ["APP_CPU_REQUEST"]="requests.cpu"
    ["APP_CPU_LIMIT"]="limits.cpu"
    ["APP_MEM_REQUEST"]="requests.memory"
    ["APP_MEM_LIMIT"]="limits.memory"
)

for env_name in "${!required_envs[@]}"; do
    resource_field="${required_envs[$env_name]}"
    
    # Check if environment variable exists
    ENV_EXISTS=$(kubectl get pod react-frontend-monitor -n react-frontend -o json | \
        jq -r ".spec.containers[] | select(.name==\"monitor-agent\") | .env[]? | select(.name==\"$env_name\") | .name")
    
    if [ -z "$ENV_EXISTS" ]; then
        echo -e "${RED}❌ FAIL: Environment variable $env_name not found${NC}"
        exit 1
    fi
    
    # Verify it uses resourceFieldRef
    USES_RESOURCE_REF=$(kubectl get pod react-frontend-monitor -n react-frontend -o json | \
        jq -r ".spec.containers[] | select(.name==\"monitor-agent\") | .env[]? | select(.name==\"$env_name\") | .valueFrom.resourceFieldRef.resource")
    
    if [ "$USES_RESOURCE_REF" != "$resource_field" ]; then
        echo -e "${RED}❌ FAIL: $env_name does not reference correct resource field (expected: $resource_field, got: $USES_RESOURCE_REF)${NC}"
        exit 1
    fi
    
    # Verify container name
    CONTAINER_NAME=$(kubectl get pod react-frontend-monitor -n react-frontend -o json | \
        jq -r ".spec.containers[] | select(.name==\"monitor-agent\") | .env[]? | select(.name==\"$env_name\") | .valueFrom.resourceFieldRef.containerName")
    
    if [ "$CONTAINER_NAME" != "frontend-app" ]; then
        echo -e "${RED}❌ FAIL: $env_name does not reference correct container (expected: frontend-app, got: $CONTAINER_NAME)${NC}"
        exit 1
    fi
    
    # Verify divisor
    DIVISOR=$(kubectl get pod react-frontend-monitor -n react-frontend -o json | \
        jq -r ".spec.containers[] | select(.name==\"monitor-agent\") | .env[]? | select(.name==\"$env_name\") | .valueFrom.resourceFieldRef.divisor")
    
    if [[ "$env_name" == *"CPU"* ]]; then
        if [ "$DIVISOR" != "1m" ]; then
            echo -e "${RED}❌ FAIL: $env_name does not use correct divisor (expected: 1m, got: $DIVISOR)${NC}"
            exit 1
        fi
    else
        if [ "$DIVISOR" != "1Mi" ]; then
            echo -e "${RED}❌ FAIL: $env_name does not use correct divisor (expected: 1Mi, got: $DIVISOR)${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓${NC} $env_name correctly configured"
done

# Wait a moment for container to start logging
sleep 3

# Check if logs contain the expected values
echo ""
echo "Checking monitor output..."

LOGS=$(kubectl logs react-frontend-monitor -n react-frontend -c monitor-agent --tail=10 2>/dev/null)

# Check for CPU request value
if echo "$LOGS" | grep -q "CPU_REQ=100m" || echo "$LOGS" | grep -q "CPU Request  : 100m"; then
    echo -e "${GREEN}✓${NC} CPU Request value correctly displayed (100m)"
else
    echo -e "${RED}❌ FAIL: CPU Request value not found or incorrect in logs${NC}"
    echo "Expected to find: CPU_REQ=100m or CPU Request  : 100m"
    exit 1
fi

# Check for CPU limit value
if echo "$LOGS" | grep -q "CPU_LIM=500m" || echo "$LOGS" | grep -q "CPU Limit    : 500m"; then
    echo -e "${GREEN}✓${NC} CPU Limit value correctly displayed (500m)"
else
    echo -e "${RED}❌ FAIL: CPU Limit value not found or incorrect in logs${NC}"
    echo "Expected to find: CPU_LIM=500m or CPU Limit    : 500m"
    exit 1
fi

# Check for Memory request value
if echo "$LOGS" | grep -q "MEM_REQ=128Mi" || echo "$LOGS" | grep -q "Mem Request: 128Mi"; then
    echo -e "${GREEN}✓${NC} Memory Request value correctly displayed (128Mi)"
else
    echo -e "${RED}❌ FAIL: Memory Request value not found or incorrect in logs${NC}"
    echo "Expected to find: MEM_REQ=128Mi or Mem Request: 128Mi"
    exit 1
fi

# Check for Memory limit value
if echo "$LOGS" | grep -q "MEM_LIM=256Mi" || echo "$LOGS" | grep -q "Mem Limit  : 256Mi"; then
    echo -e "${GREEN}✓${NC} Memory Limit value correctly displayed (256Mi)"
else
    echo -e "${RED}❌ FAIL: Memory Limit value not found or incorrect in logs${NC}"
    echo "Expected to find: MEM_LIM=256Mi or Mem Limit  : 256Mi"
    exit 1
fi

echo ""
echo "========================================"
echo -e "${GREEN}✅ ALL CHECKS PASSED!${NC}"
echo "========================================"
echo ""
echo "The Downward API has been correctly configured."
echo "The monitor-agent can now access the frontend-app container's resource specifications."
