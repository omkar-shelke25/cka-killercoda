# 🔐 **CKA: Certificate Management and Control-Plane Audit**

📚 **Official Kubernetes Documentation**: 
- [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
- [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [kubeadm config images](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-config/)

### 🎯 **Context**

Your organization is preparing for a scheduled security audit on its Kubernetes cluster, which was originally deployed using kubeadm. 

As part of the audit readiness process, you have been assigned to validate certificate health and confirm the control-plane image baselines.

The security team requires documented proof of:
1. Current certificate expiration status
2. Updated certificates after renewal
3. Expected control-plane component images

Your task is to perform these audit tasks and store the evidence in the specified files.

### ❓ **Question**

Complete the following tasks as part of the security audit:

**Task 1: Audit current certificate status**

Check and record the expiration details of all certificates managed by kubeadm. Save the full output to:
```
/k8s/cert-details-old.txt
```

**Task 2: Perform certificate rotation**

Renew all kubeadm-managed control-plane certificates to ensure compliance with security policy. After renewal, re-check the expiration details and store the updated output in:
```
/k8s/cert-details-new.txt
```

**Task 3: Document required control-plane images**

Retrieve the list of container images that kubeadm expects for the cluster's control-plane components and save the output to:
```
/k8s/image-list.txt
```

**Important Notes:**
- All commands must be executed on the control-plane node
- Ensure you use `sudo` where necessary for privileged operations
- Do not delete or modify any existing cluster resources
- The cluster must remain operational throughout the process

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: SSH to the control-plane node (if not already there)**

```bash
# If you're on a worker node, SSH to the control-plane
ssh controlplane
# or
ssh node01  # depending on your environment setup
```

For Killercoda, you should already be on the control-plane node.

**Step 2: Check current certificate status and save to file**

```bash
sudo kubeadm certs check-expiration > /k8s/cert-details-old.txt
```

View the current certificate status:
```bash
cat /k8s/cert-details-old.txt
```

You should see output showing all certificates with their expiration dates, typically something like:
```
CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Jan 15, 2026 10:30 UTC   51d             ca                      no      
apiserver                  Jan 15, 2026 10:30 UTC   51d             ca                      no      
...
```

**Step 3: Renew all kubeadm-managed certificates**

```bash
sudo kubeadm certs renew all
```

This command will output confirmation messages for each renewed certificate:
```
certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself renewed
certificate for serving the Kubernetes API renewed
...
```

**Step 4: Check updated certificate status after renewal**

```bash
sudo kubeadm certs check-expiration > /k8s/cert-details-new.txt
```

View the updated certificate status:
```bash
cat /k8s/cert-details-new.txt
```

You should now see updated expiration dates, typically extended by 1 year from the renewal date.

**Step 5: Compare old and new certificate expiration dates**

```bash
echo "=== OLD CERTIFICATES ==="
cat /k8s/cert-details-old.txt
echo ""
echo "=== NEW CERTIFICATES ==="
cat /k8s/cert-details-new.txt
```

**Step 6: Restart control-plane components to use new certificates**

```bash
# Restart kubelet to pick up new certificates
sudo systemctl restart kubelet
```

Wait for the control-plane to be ready:
```bash
kubectl wait --for=condition=Ready nodes --all --timeout=180s
```

**Step 7: Retrieve control-plane image list**

```bash
kubeadm config images list > /k8s/image-list.txt
```

View the control-plane images:
```bash
cat /k8s/image-list.txt
```

You should see output like:
```
registry.k8s.io/kube-apiserver:v1.28.2
registry.k8s.io/kube-controller-manager:v1.28.2
registry.k8s.io/kube-scheduler:v1.28.2
registry.k8s.io/kube-proxy:v1.28.2
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.9-0
registry.k8s.io/coredns/coredns:v1.10.1
```

**Step 8: Verify cluster is operational**

```bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

</details>
