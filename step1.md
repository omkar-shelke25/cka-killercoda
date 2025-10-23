# 📝 Task: Write Script to List Static Pods

## Background

Static pods are managed directly by the kubelet daemon on a specific node, without the API server observing them. The kubelet watches static pod manifests in a specific directory (typically `/etc/kubernetes/manifests/`) and automatically creates/manages these pods.

**Important:** Static pods automatically get the **node hostname as a suffix** in their pod name:
- Example: `httpd-web-controlplane`, `ai-apps-node01`

## Your Mission

Create a shell script named **`list-static-pods.sh`** in the home directory (`/root/`) that lists all static pods running in the cluster.

### Requirements:

1. **Script location:** `/root/list-static-pods.sh`
2. **Must be executable:** `chmod +x`
3. **Must have shebang:** `#!/bin/bash`
4. **Must identify static pods** on both control plane and worker nodes
5. **Must show:** Pod name, namespace, and status

## Cluster Information:

- **Nodes:** controlplane, node01
- **Static Pods:**
  - Control plane: `httpd-web-controlplane` in namespace `infra-space`
  - Worker: `ai-apps-node01` in namespace `ai-space`

## Key Concept:

Static pods have the node name as a **suffix** in their pod name. So you can identify them by grepping for the node names in the pod list!

Example:
```
httpd-web-controlplane  → static pod on controlplane node
ai-apps-node01          → static pod on node01 node
```

## Hints:

<details>
<summary>💡 Hint 1: Understanding Static Pod Names</summary>

Static pods are automatically named with the pattern: `<pod-name>-<node-hostname>`

For example:
- Original manifest name: `httpd-web.yaml`
- Node hostname: `controlplane`
- Resulting pod name: `httpd-web-controlplane`

This means you can filter pods by looking for node names in the pod name itself!
</details>

<details>
<summary>💡 Hint 2: Simple kubectl Command</summary>

You can list all pods across namespaces with:
```bash
kubectl get pods -A
```

Then filter for pods that have node names in their names:
```bash
kubectl get pods -A | grep -E 'controlplane|node01'
```

The `-A` flag shows all namespaces, so you'll see both `infra-space` and `ai-space` pods.
</details>

<details>
<summary>💡 Hint 3: Creating the Script</summary>

You need to create a file with:
1. Shebang line: `#!/bin/bash`
2. The kubectl command to list static pods
3. Make it executable: `chmod +x`

You can create it with:
```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
kubectl get pods -A | grep -E 'controlplane|node01'
EOF

chmod +x /root/list-static-pods.sh
```
</details>

<details>
<summary>✅ Complete Solution</summary>

**Method 1: Using cat (Recommended)**

```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
kubectl get pods -A | grep -E 'controlplane|node01'
EOF

chmod +x /root/list-static-pods.sh
```

**Method 2: Using echo**

```bash
echo '#!/bin/bash' > /root/list-static-pods.sh
echo "kubectl get pods -A | grep -E 'controlplane|node01'" >> /root/list-static-pods.sh
chmod +x /root/list-static-pods.sh
```

**Method 3: With better formatting**

```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
echo "=== Static Pods in Cluster ==="
kubectl get pods -A | grep -E 'controlplane|node01'
EOF

chmod +x /root/list-static-pods.sh
```

**Method 4: More robust version**

```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "    Static Pods Discovery"
echo "=============================================="
echo ""

# Get all pods and filter by node name suffix
kubectl get pods -A | head -1
kubectl get pods -A | grep -E 'controlplane|node01'

echo ""
echo "=============================================="
EOF

chmod +x /root/list-static-pods.sh
```

### Why This Works:

1. **`kubectl get pods -A`** - Lists all pods in all namespaces
2. **`grep -E 'controlplane|node01'`** - Filters for static pods by matching node names in pod names
3. Static pods have node hostname as suffix, so this catches them all!

### Test Your Script:

```bash
# Run the script
/root/list-static-pods.sh
```

Expected output:
```
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
infra-space   httpd-web-controlplane     1/1     Running   0          5m
ai-space      ai-apps-node01             1/1     Running   0          5m
```

</details>

## Explanation:

The beauty of this solution is its simplicity:

1. **Static pods are named with node suffix** - Kubernetes automatically appends the node hostname
2. **No need for -o wide** - The node name is already in the pod name itself
3. **grep filters by pod name** - Not by the node column, but by the pod name pattern
4. **Works for 2-node cluster** - Covers both controlplane and node01

## Alternative Approaches (Optional):

<details>
<summary>Using jq (more precise)</summary>

```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.metadata.ownerReferences[]?.kind=="Node") |
  "\(.metadata.namespace)\t\(.metadata.name)\t\(.status.phase)"
' | column -t
EOF

chmod +x /root/list-static-pods.sh
```

This checks the owner reference to confirm they're static pods.
</details>

<details>
<summary>Checking manifest files</summary>

```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
echo "=== Control Plane Static Pods ==="
ls -1 /etc/kubernetes/manifests/*.yaml 2>/dev/null | xargs -I {} basename {}

echo ""
echo "=== Worker Node Static Pods ==="
ssh node01 'ls -1 /etc/kubernetes/manifests/*.yaml 2>/dev/null' | xargs -I {} basename {}
EOF

chmod +x /root/list-static-pods.sh
```

This checks the actual manifest files on disk.
</details>

## Testing:

```bash
# Make executable
chmod +x /root/list-static-pods.sh

# Run the script
/root/list-static-pods.sh

# Verify output shows both pods
/root/list-static-pods.sh | grep -c "httpd-web"  # Should be 1
/root/list-static-pods.sh | grep -c "ai-apps"    # Should be 1
```

## Quick One-Liner Solution:

If you just want the fastest solution:

```bash
cat > /root/list-static-pods.sh << 'EOF'
#!/bin/bash
kubectl get pods -A | grep -E 'controlplane|node01'
EOF
chmod +x /root/list-static-pods.sh
```

That's it! Simple, effective, and exactly what you need for this scenario. 🚀
