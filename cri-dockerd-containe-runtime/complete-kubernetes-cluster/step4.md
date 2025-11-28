# Step 4: Initialize Master Node and Configure kubectl 🎛️

## 📚 Documentation Reference
- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [kubeadm init](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)

## 🎯 Objective

Initialize the Kubernetes control plane on the master node and configure kubectl for cluster management.

## 🧠 Why This Matters

The `kubeadm init` command:
- Creates the control plane components (API server, scheduler, controller manager, etcd)
- Generates certificates for secure communication
- Creates the kubeconfig file for cluster access
- Provides the join command for worker nodes

---

## 📋 Tasks

### Task 4.1: Get the Node's IP Address

First, find your node's IP address:

```bash
hostname -I | awk '{print $1}'
```

💡 **Note**: Use this IP as `--apiserver-advertise-address` in the next command.

---

### Task 4.2: Initialize the Cluster

🔴 **CRITICAL STEP**: Initialize the Kubernetes control plane.

Replace `<YOUR_NODE_IP>` with the IP from above:

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<YOUR_NODE_IP> \
  --kubernetes-version=v1.31.0
```

**Parameters explained:**
- `--pod-network-cidr`: IP range for pod network (required for Calico CNI)
- `--apiserver-advertise-address`: IP address the API server will advertise
- `--kubernetes-version`: Explicit version specification

⏱️ **Wait time**: 2-5 minutes for initialization to complete.

---

### 📝 IMPORTANT: Save the Output!

The output contains:
1. **kubectl configuration commands** (for master node)
2. **kubeadm join command** (for worker nodes)

**Example output:**
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.100:6443 --token abc123.xyz789 \
	--discovery-token-ca-cert-hash sha256:abcd1234...
```

🔴 **SAVE THIS OUTPUT** - You'll need the join command for Step 6!

You can save it to a file:
```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<YOUR_NODE_IP> \
  --kubernetes-version=v1.31.0 \
  | tee /root/cluster-setup/init-output.txt
```

---

### Task 4.3: Configure kubectl for the Master Node

Run these commands to set up kubectl access:

```bash
mkdir -p $HOME/.kube
```

```bash
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**What this does:**
- Creates the kubectl configuration directory
- Copies the admin credentials
- Sets proper file ownership

---

### Task 4.4: Verify Cluster Initialization

Check cluster information:

```bash
kubectl cluster-info
```

Expected output:
```
Kubernetes control plane is running at https://<IP>:6443
CoreDNS is running at https://<IP>:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Check node status:

```bash
kubectl get nodes
```

Expected output:
```
NAME          STATUS     ROLES           AGE   VERSION
controlplane  NotReady   control-plane   1m    v1.31.0
```

⚠️ **Note**: Status shows `NotReady` because CNI (pod network) is not yet installed. This is expected!

---

## ✅ Verification Checklist

Before proceeding, ensure:

- [ ] `kubeadm init` completed successfully
- [ ] Join command is saved for worker nodes
- [ ] kubectl configuration directory exists (`~/.kube/`)
- [ ] kubectl can connect to the cluster
- [ ] `kubectl cluster-info` shows control plane running
- [ ] `kubectl get nodes` shows the master node (NotReady is OK)

---

## 🔍 Troubleshooting

**Problem**: "Port 6443 is already in use"
- **Solution**: Another process is using the API server port
- Check: `sudo lsof -i :6443`
- If previous init failed: `sudo kubeadm reset` then try again

**Problem**: "kubelet is not running or healthy"
- **Solution**: Check kubelet status: `sudo systemctl status kubelet`
- Restart: `sudo systemctl restart kubelet`

**Problem**: "Unable to connect to the server"
- **Solution**: Verify kubectl config is copied correctly
- Check: `ls -la ~/.kube/config`

**Problem**: Lost join command
- **Solution**: Generate a new one:
  ```bash
  kubeadm token create --print-join-command
  ```

---

## 📝 What You Learned

- Control plane initialization process
- kubeadm init parameters and their purposes
- kubectl configuration setup
- Cluster authentication and authorization
- Understanding node readiness states

---

**Ready?** Click **Continue** to proceed to Step 5! ➡️
