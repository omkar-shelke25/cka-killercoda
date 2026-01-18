# 🌐 **CKA: CoreDNS Configuration and Custom Domain**

📚 **Official Kubernetes Documentation**: 
- [Customizing DNS Service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)
- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [CoreDNS Documentation](https://coredns.io/manual/toc/)

### 🏢 **Context**

You are the cluster administrator responsible for DNS configuration. The development team needs to access services using a custom domain `killercoda.com` **alongside** the default `cluster.local` domain.

The CoreDNS configuration needs to be updated to support **both domains simultaneously**:
- `SERVICE.NAMESPACE.svc.cluster.local` (default - must continue working)
- `SERVICE.NAMESPACE.svc.killercoda.com` (custom - new requirement)

**Critical Requirement:** Both DNS domains must resolve to the **same services** at the **same time**. Services should be accessible via either domain.

### ❓ **Tasks**

#### **Task 1: Backup CoreDNS Configuration**

Make a backup of the existing CoreDNS configuration and store it at `/opt/course/16/coredns_backup.yaml`. The backup should be in a format that allows fast recovery.

#### **Task 2: Update CoreDNS Configuration**

Update the CoreDNS configuration in the cluster so that DNS resolution for `SERVICE.NAMESPACE.svc.killercoda.com` will work **alongside** and **in addition to** `SERVICE.NAMESPACE.svc.cluster.local`.

**Important:** Both domains must work simultaneously. Do NOT replace cluster.local - add killercoda.com as an additional domain.

#### **Task 3: Test DNS Resolution**

Test your configuration from a Pod with `busybox:1.35` image. **Both** of these commands should result in an IP address:

```bash
nslookup kubernetes.default.svc.cluster.local
nslookup kubernetes.default.svc.killercoda.com
```

**Expected Result:** Both commands should return the **same IP address**, proving both domains work simultaneously.

---

### 💡 **Understanding CoreDNS**

<details><summary>🔍 CoreDNS Architecture</summary>

**CoreDNS Components:**
```
Pod → DNS Query → CoreDNS Pod → ConfigMap → DNS Response
```

**CoreDNS Configuration:**
- Stored in ConfigMap: `coredns` in `kube-system` namespace
- Uses Corefile syntax
- Plugins handle different DNS functions

**Default Configuration:**
```
.:53 {
    errors
    health
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

</details>

<details><summary>🔍 DNS Names in Kubernetes</summary>

**Service DNS Format:**
```
<service-name>.<namespace>.svc.<cluster-domain>
```

**Examples:**
- `kubernetes.default.svc.cluster.local`
- `my-service.my-namespace.svc.cluster.local`

**Short Names (within same namespace):**
- `my-service` (same namespace)
- `my-service.other-namespace` (different namespace)

</details>

<details><summary>🔍 Adding Custom Domains Alongside cluster.local</summary>

**Dual Domain Support:**

To add a custom domain **alongside** `cluster.local` (not replacing it), you modify the kubernetes plugin to include both domains:

**Original (single domain):**
```
kubernetes cluster.local in-addr.arpa ip6.arpa {
   pods insecure
   fallthrough in-addr.arpa ip6.arpa
}
```

**Updated (dual domain support):**
```
kubernetes cluster.local killercoda.com in-addr.arpa ip6.arpa {
   pods insecure
   fallthrough in-addr.arpa ip6.arpa
}
```

**What this means:**
- Both domains are space-separated on the same line
- CoreDNS will handle queries for BOTH domains
- Services are accessible via EITHER domain
- Both domains resolve to the SAME services

**Example:**
```bash
# Both commands return the same IP:
kubernetes.default.svc.cluster.local   → 10.96.0.1
kubernetes.default.svc.killercoda.com  → 10.96.0.1 (same IP!)
```

**Important:** Do NOT create separate kubernetes plugin blocks - use a single line with multiple domains.

</details>

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Create backup directory (if not exists)**

```bash
mkdir -p /opt/course/16
```

**Step 2: Backup CoreDNS ConfigMap**

```bash
kubectl get configmap coredns -n kube-system -o yaml > /opt/course/16/coredns_backup.yaml
```

Verify backup was created:
```bash
ls -lh /opt/course/16/coredns_backup.yaml
cat /opt/course/16/coredns_backup.yaml
```

**Step 3: View current CoreDNS configuration**

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

Look for the `Corefile` data section.

**Step 4: Edit CoreDNS ConfigMap**

```bash
kubectl edit configmap coredns -n kube-system
```

Find this line in the Corefile:
```
kubernetes cluster.local in-addr.arpa ip6.arpa {
```

Change it to:
```
kubernetes cluster.local killercoda.com in-addr.arpa ip6.arpa {
```

Save and exit the editor.

**Alternative: Using kubectl patch**

```bash
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-config.yaml

# Edit the file
sed -i 's/kubernetes cluster.local in-addr.arpa/kubernetes cluster.local killercoda.com in-addr.arpa/g' /tmp/coredns-config.yaml

# Apply the changes
kubectl apply -f /tmp/coredns-config.yaml
```

**Step 5: Restart CoreDNS pods (to pick up changes)**

CoreDNS has a reload plugin, but for immediate effect, restart the pods:

```bash
kubectl rollout restart deployment coredns -n kube-system
```

Wait for CoreDNS to be ready:
```bash
kubectl rollout status deployment coredns -n kube-system
```

**Step 6: Verify CoreDNS configuration**

```bash
kubectl get configmap coredns -n kube-system -o yaml | grep -A 3 "kubernetes"
```

You should see both `cluster.local` and `killercoda.com`.

**Step 7: Test DNS resolution with cluster.local (MUST still work)**

```bash
kubectl run test-dns-1 --image=busybox:1.35 -it --rm -- nslookup kubernetes.default.svc.cluster.local
```

Expected output:
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

**Important:** cluster.local MUST still work! We added killercoda.com alongside it, not replacing it.

**Step 8: Test DNS resolution with killercoda.com (NEW domain)**

```bash
kubectl run test-dns-2 --image=busybox:1.35 -it --rm -- nslookup kubernetes.default.svc.killercoda.com
```

Expected output:
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default.svc.killercoda.com
Address 1: 10.96.0.1 kubernetes.default.svc.killercoda.com
```

**Verify:** The IP address (10.96.0.1) should be **identical** in both tests, confirming both domains work simultaneously.

**Step 9: Test with test-service (verify both domains)**

```bash
# Test cluster.local domain (original)
kubectl run test-dns-3 --image=busybox:1.35 -it --rm -- nslookup test-service.test-dns.svc.cluster.local

# Test killercoda.com domain (new)
kubectl run test-dns-4 --image=busybox:1.35 -it --rm -- nslookup test-service.test-dns.svc.killercoda.com
```

Both should return the **same IP address**, proving dual DNS support works correctly.

**Step 10: Verify backup can restore configuration**

If needed to restore:
```bash
kubectl apply -f /opt/course/16/coredns_backup.yaml
kubectl rollout restart deployment coredns -n kube-system
```

**Understanding the Configuration:**

The updated Corefile section:
```
.:53 {
    errors
    health
    kubernetes cluster.local killercoda.com in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

**Key change:**
```
kubernetes cluster.local killercoda.com in-addr.arpa ip6.arpa
```

This tells CoreDNS to handle DNS queries for both:
- `*.cluster.local`
- `*.killercoda.com`

And resolve them to the same Kubernetes services.

**Verification Checklist:**
- ✅ Backup created at /opt/course/16/coredns_backup.yaml
- ✅ CoreDNS ConfigMap updated with killercoda.com
- ✅ CoreDNS pods restarted
- ✅ kubernetes.default.svc.cluster.local resolves
- ✅ kubernetes.default.svc.killercoda.com resolves
- ✅ Both domains return same IP address

</details>

---

### 🧪 **Additional Testing**

<details><summary>Advanced DNS testing commands</summary>

```bash
# Test from within a pod
kubectl run -it --rm debug --image=busybox:1.35 -- sh

# Inside the pod:
nslookup kubernetes.default
nslookup kubernetes.default.svc
nslookup kubernetes.default.svc.cluster.local
nslookup kubernetes.default.svc.killercoda.com

# Test all services
nslookup test-service.test-dns.svc.cluster.local
nslookup test-service.test-dns.svc.killercoda.com

# Check DNS server
cat /etc/resolv.conf

# Exit pod
exit
```

```bash
# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Check CoreDNS metrics
kubectl get --raw /api/v1/namespaces/kube-system/services/kube-dns:metrics/proxy/metrics
```

</details>

---

### 📝 **Quick Reference**

**CoreDNS Files:**
```
ConfigMap: coredns (namespace: kube-system)
Deployment: coredns (namespace: kube-system)
Service: kube-dns (namespace: kube-system)
```

**Key Commands:**
```bash
# Backup
kubectl get cm coredns -n kube-system -o yaml > backup.yaml

# Edit
kubectl edit cm coredns -n kube-system

# Restart
kubectl rollout restart deployment coredns -n kube-system

# Test
kubectl run test --image=busybox:1.35 -it --rm -- nslookup <domain>
```

**DNS Format:**
```
<service>.<namespace>.svc.<domain>
kubernetes.default.svc.cluster.local
kubernetes.default.svc.killercoda.com
```
