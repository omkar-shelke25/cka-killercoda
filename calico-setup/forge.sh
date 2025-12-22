#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Kubernetes cluster installation is in progress...${NC}"
echo -e "${YELLOW}Please wait for about 2 minutes.${NC}\n"

echo -e "${BLUE}You can check the container runtime status using:${NC}"
echo -e "${CYAN}  systemctl status containerd${NC}\n"

echo -e "${BLUE}You can list running containers using:${NC}"
echo -e "${CYAN}  crictl ps${NC}\n"

echo -e "${GREEN}Installation checks completed. Monitoring continues...${NC}"
