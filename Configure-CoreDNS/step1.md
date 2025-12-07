# 🧠 **CKA: Configure CoreDNS with Upstream DNS Servers**

📚 **Official Kubernetes Documentation**: 
- [Customizing DNS Service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [CoreDNS Documentation](https://coredns.io/manual/toc/)
- [CoreDNS forward plugin](https://coredns.io/plugins/forward/)

### 🎯 **Context**

You are working 🧑‍💻 as a Kubernetes administrator for an organization that requires all DNS queries for external domains to be resolved through specific upstream DNS servers for compliance and monitoring purposes.

The organization has mandated the use of Google DNS (8.8.8.8) and Cloudflare DNS (1.1.1.1) as the upstream resolvers. You need to configure CoreDNS accordingly and verify that the configuration works correctly.

### ❓ **Question**

Configure the cluster so that CoreDNS uses the following upstream DNS servers:
- 8.8.8.8 (Google DNS)
- 1.1.1.1 (Cloudflare DNS)

Then complete the following tasks:

1. **Create a temporary pod for DNS testing** using an image that has DNS tools (like `busybox` or `nicolaka/netshoot`)

2. **From this pod, run `nslookup` commands** to test DNS resolution:
   - Use `nslookup kubernetes.io 8.8.8.8`
   - Use `nslookup kubernetes.io 1.1.1.1`

3. **Redirect the output of both commands** into the file `/root/dns-server.txt`

**Requirements:**
- The CoreDNS configuration must use both 8.8.8.8 and 1.1.1.1 as upstream DNS servers
- The output file must contain results from both nslookup commands
- Do not delete or modify any existing cluster resources other than the CoreDNS ConfigMap
- Ensure CoreDNS pods are restarted to apply the new configuration

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Edit the CoreDNS ConfigMap**

First, check the current CoreDNS configuration:
```bash
kubectl get configmap coredns -n kube-system -o yaml
```

Edit the CoreDNS ConfigMap:
```bash
kubectl edit configmap coredns -n kube-system
```

Find the `forward` section in the Corefile. The default configuration typically looks like:
```
forward . /etc/resolv.conf
```

Replace it with:
```
forward . 8.8.8.8 1.1.1.1
```

The complete Corefile should look similar to this:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . 8.8.8.8 1.1.1.1
        cache 30
        loop
        reload
        loadbalance
    }
```

Save and exit the editor.

**Alternative: Using kubectl patch**
```bash
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns.yaml

# Edit the file to change forward line
sed -i 's|forward . /etc/resolv.conf|forward . 8.8.8.8 1.1.1.1|g' /tmp/coredns.yaml

# Apply the changes
kubectl apply -f /tmp/coredns.yaml
```

**Step 2: Restart CoreDNS pods to apply changes**

```bash
kubectl rollout restart deployment coredns -n kube-system
```

Wait for CoreDNS pods to be ready:
```bash
kubectl wait --for=condition=Ready pods -l k8s-app=kube-dns -n kube-system --timeout=60s
```

Verify CoreDNS pods are running:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Step 3: Create a temporary test pod**

```bash
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- sh
```

Or if you prefer a pod with more networking tools:
```bash
kubectl run dns-test --image=nicolaka/netshoot --rm -it --restart=Never -- bash
```

**Step 4: Run nslookup commands from the pod**

If using busybox:
```bash
# Inside the pod
nslookup kubernetes.io 8.8.8.8
nslookup kubernetes.io 1.1.1.1
exit
```

**Step 5: Run nslookup from host and save output**

Since we need to save the output to `/root/dns-server.txt` on the host (not inside the pod), we'll run the commands differently:

```bash
# Create a pod without interactive mode
kubectl run dns-test --image=busybox:1.28 --restart=Never -- sleep 3600

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/dns-test --timeout=60s

# Run nslookup commands and save output
kubectl exec dns-test -- nslookup kubernetes.io 8.8.8.8 > /root/dns-server.txt
kubectl exec dns-test -- nslookup kubernetes.io 1.1.1.1 >> /root/dns-server.txt

# Clean up the test pod
kubectl delete pod dns-test
```

**Alternative approach using temporary pod:**
```bash
# Run first nslookup
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -i -- nslookup kubernetes.io 8.8.8.8 > /root/dns-server.txt

# Run second nslookup and append
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -i -- nslookup kubernetes.io 1.1.1.1 >> /root/dns-server.txt
```

**Step 6: Verify the output**

```bash
cat /root/dns-server.txt
```

Expected output should show DNS resolution results from both servers:
```
Server:    8.8.8.8
Address 1: 8.8.8.8 dns.google

Name:      kubernetes.io
Address 1: ...

Server:    1.1.1.1
Address 1: 1.1.1.1 one.one.one.one

Name:      kubernetes.io
Address 1: ...
```

**Verification checklist:**
- ✅ CoreDNS ConfigMap updated with forward . 8.8.8.8 1.1.1.1
- ✅ CoreDNS pods restarted and running
- ✅ DNS test pod created and used for testing
- ✅ nslookup results for both DNS servers saved to /root/dns-server.txt
- ✅ Output file contains responses from both 8.8.8.8 and 1.1.1.1

**Additional verification:**

Test DNS resolution from any pod:
```bash
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.io
```

Check CoreDNS logs:
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

</details>

---

