# 🧠 **CKA: Recover API Server from Certificate Deletion**

📚 **Official Kubernetes Documentation**: 
- [PKI Certificates and Requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
- [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)

### 🔥 **Context**

Your company uses an automated script to rotate Kubernetes control-plane certificates every 365 days. 

Due to a bug in a recent update, the automation deleted the API server TLS files `/etc/kubernetes/pki/apiserver.crt` and `/etc/kubernetes/pki/apiserver.key` instead of renewing them.

At first, everything seemed fine because the kube-apiserver was still running with the certificates already loaded in memory. However, later that night, a routine node security patch caused kubelet to restart, which triggered all static pods—including the kube-apiserver—to restart.

After the restart, the kube-apiserver container failed to start and is stuck in a CrashLoopBackOff state. `kubectl` no longer works from any node or admin workstation.


### ❓ **Question**

Your task is to restore the Kubernetes API server to full operational status. 

Regenerate the missing API server certificate and key using kubeadm, restart the API server successfully, and verify that kubectl functionality has been restored. 

The cluster should be fully operational with all control plane components running.

Do not manually create certificates using OpenSSL or any other tools.

Use `kubeadm` built-in certificate management commands.

Do not modify or touch any other certificates or configurations beyond what is necessary to complete the recovery.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

Here is the **answer only**, with **icons**, short and clean:

---

## ✅ **Answer**

🔧 **Regenerate API server certificates**

```bash
sudo kubeadm init phase certs apiserver
```

🔄 **Restart kubelet to recreate static pods**

```bash
sudo systemctl restart kubelet.service
```

📦 **Verify kube-apiserver container**

```bash
crictl ps
```

📊 **Check cluster status**

```bash
kubectl get pods -A
```

</details>
