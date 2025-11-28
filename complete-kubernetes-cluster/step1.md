# Step 1: System Preparation and Prerequisites 🔧

## 📚 Documentation Reference
- [Installing kubeadm - Before you begin](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#before-you-begin)
- [Container Runtime Prerequisites](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#prerequisites)

## 🎯 Objective

Prepare the system for Kubernetes installation by updating packages, disabling swap, loading kernel modules, and configuring network parameters.

## 🧠 Why This Matters

Kubernetes has specific system requirements:
- **No swap**: Kubelet requires swap to be disabled for performance and stability
- **Kernel modules**: Enable container networking and storage features
- **Network parameters**: Allow proper pod-to-pod and pod-to-service communication

---

## 📋 Tasks

### Task 1.1: Update System Packages

Update all system packages to ensure security patches and compatibility:

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

💡 **Tip**: This may take a few minutes depending on available updates.

---

### Task 1.2: Disable Swap

Kubernetes requires swap to be disabled:

```bash
sudo swapoff -a
```

Make it permanent by editing `/etc/fstab`:

```bash
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

**Verify swap is disabled:**
```bash
free -h
```

Expected output: Swap line should show `0B` or be absent.

---

### Task 1.3: Load Required Kernel Modules

Create a configuration file for kernel modules:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

Load the modules immediately:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

**Verify modules are loaded:**
```bash
lsmod | grep br_netfilter
lsmod | grep overlay
```

Expected output: Both modules should appear in the list.

---

### Task 1.4: Configure Kernel Parameters for Networking

Create sysctl configuration for Kubernetes networking:

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```

Apply the settings:

```bash
sudo sysctl --system
```

**Verify the settings:**
```bash
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

Expected output: All values should be `= 1`

---

## ✅ Verification Checklist

Before proceeding to the next step, ensure:

- [ ] System packages are updated
- [ ] Swap is disabled (verify with `free -h`)
- [ ] Kernel modules `overlay` and `br_netfilter` are loaded
- [ ] Network parameters are configured correctly
- [ ] All verification commands show expected results

---

## 🔍 Troubleshooting

**Problem**: "modprobe: FATAL: Module overlay not found"
- **Solution**: Update your kernel: `sudo apt-get install linux-modules-extra-$(uname -r)`

**Problem**: Swap shows non-zero values
- **Solution**: Ensure you ran `swapoff -a` and modified `/etc/fstab`

---

## 📝 What You Learned

- System prerequisites for Kubernetes installation
- Importance of disabling swap for kubelet
- Kernel modules required for container networking
- Network bridge and IP forwarding configuration

---

**Ready?** Click **Continue** to proceed to Step 2! ➡️
