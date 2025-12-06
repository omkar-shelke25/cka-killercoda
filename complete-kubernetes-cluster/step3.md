# Step 3: Install Kubernetes Components (kubeadm, kubelet, kubectl) ☸️

## 📚 Documentation Reference
- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)

## 🎯 Objective

Install the three essential Kubernetes components:
- **kubeadm**: Tool to bootstrap the cluster
- **kubelet**: Node agent that runs on every node
- **kubectl**: Command-line tool to interact with the cluster

## 🧠 Why This Matters

These components work together:
- **kubeadm** creates and manages the control plane
- **kubelet** ensures containers are running in pods
- **kubectl** allows you to manage cluster resources

---

## 📋 Tasks

### Task 3.1: Add Kubernetes Repository GPG Key

Download and add the Kubernetes GPG key for package verification:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

💡 **Note**: We're using v1.31 (latest stable Kubernetes version)

---

### Task 3.2: Add Kubernetes Repository

Add the Kubernetes package repository:

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update the package list:

```bash
sudo apt-get update
```

---

### Task 3.3: Install Kubernetes Components

Install kubeadm, kubelet, and kubectl:

```bash
sudo apt-get install -y kubelet kubeadm kubectl
```

💡 **Tip**: This may take a few minutes to download and install.

---

### Task 3.4: Hold Package Versions

Prevent automatic updates of Kubernetes components (important for cluster stability):

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

**Why hold packages?**
- Prevents accidental version mismatches
- Allows controlled cluster upgrades
- Ensures version consistency across nodes

---

### Task 3.5: Enable kubelet Service

Enable kubelet to start on boot:

```bash
sudo systemctl enable --now kubelet
```

⚠️ **Note**: kubelet will crash-loop until the cluster is initialized (this is normal!)

**Check status (optional):**
```bash
sudo systemctl status kubelet
```

You'll see it's active but may show errors - this is expected before cluster init.
Press `q` to exit.

---

### Task 3.6: Verify Installation

Check installed versions:

```bash
kubeadm version
```

```bash
kubectl version --client
```

```bash
kubelet --version
```

Expected output: All should show version `v1.31.x`

---

## ✅ Verification Checklist

Before proceeding, ensure:

- [ ] Kubernetes repository GPG key is added
- [ ] Kubernetes repository is configured
- [ ] kubeadm, kubelet, and kubectl are installed
- [ ] Packages are held at current version
- [ ] kubelet service is enabled
- [ ] All three components show v1.31.x version

---

## 🔍 Troubleshooting

**Problem**: "Package 'kubectl' has no installation candidate"
- **Solution**: Verify repository was added correctly
- Re-run: `sudo apt-get update`

**Problem**: Version mismatch between components
- **Solution**: Specify exact version during install:
  ```bash
  sudo apt-get install -y kubelet=1.31.x-* kubeadm=1.31.x-* kubectl=1.31.x-*
  ```

**Problem**: kubelet shows as failed
- **Solution**: This is normal before cluster initialization. It will start properly after `kubeadm init`

---

**Ready?** Click **Continue** to proceed to Step 4! ➡️
