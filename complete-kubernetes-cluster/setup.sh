#!/bin/bash
set -e



# Display node information
echo "✅ Environment prepared!"
echo ""
echo "📊 System Information:"
echo "   Hostname: $(hostname)"
echo "   OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f2)"
echo "   Kernel: $(uname -r)"
echo "   CPU: $(nproc) cores"
echo "   Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""
echo "🎯 You will set up a Kubernetes cluster on this system"
echo "📝 Progress will be tracked in /root/cluster-setup/"
echo ""
echo "Ready to begin! Proceed to Step 1. 🚀"
