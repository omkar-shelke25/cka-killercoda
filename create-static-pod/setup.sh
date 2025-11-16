#!/bin/bash
set -euo pipefail

# Create the namespace
kubectl create ns mcp-tool

sleep 3

echo "Setup complete. Namespace 'mcp-tool' has been created."
echo "You can now create the static pod manifest."
