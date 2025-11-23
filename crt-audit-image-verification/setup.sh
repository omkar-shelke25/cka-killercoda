#!/bin/bash
set -euo pipefail

# Create directory for storing audit outputs
mkdir -p /k8s

sudo apt install colordiff -y
