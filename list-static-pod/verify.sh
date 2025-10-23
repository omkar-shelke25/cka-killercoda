#!/bin/bash
# ============================================
# 🧩 Verification Script for list-static-pods.sh
# ============================================

# Colors for better output
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

echo -e "${YELLOW}🔍 Verifying static pod listing task...${RESET}"

# Step 1: Check if the script file exists
if [ ! -f /root/list-static-pods.sh ]; then
  echo -e "${RED}❌ list-static-pods.sh not found in /root directory.${RESET}"
  echo "Please create the script at /root/list-static-pods.sh."
  exit 1
fi

# Step 2: Check if the script has execute permissions
if [ ! -x /root/list-static-pods.sh ]; then
  echo -e "${RED}❌ Script does not have execute permissions.${RESET}"
  echo "Run: chmod +x /root/list-static-pods.sh"
  exit 1
fi

# Step 3: Check if it contains correct command pattern
if ! grep -qE "kubectl get pods -A|grep -E" /root/list-static-pods.sh; then
  echo -e "${RED}❌ Script content does not contain expected kubectl or grep command.${RESET}"
  echo "Expected something like: kubectl get pods -A | grep -E 'controlplane|node01'"
  exit 1
fi

# Step 4: Run the script and check output
output=$(/root/list-static-pods.sh 2>/dev/null)

if echo "$output" | grep -E 'controlplane|node01' >/dev/null; then
  echo -e "${GREEN}✅ Success! Script lists static pods correctly.${RESET}"
  echo -e "${GREEN}Output:${RESET}"
  echo "$output"
  exit 0
else
  echo -e "${RED}❌ Script did not return any static pods.${RESET}"
  echo "Make sure static pods exist and script uses correct node names."
  exit 1
fi
