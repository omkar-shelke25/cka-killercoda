# Step 2: Install and Configure Container Runtime (containerd) 🐳

## 📚 Documentation Reference
- [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [containerd Configuration](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)

## 🎯 Objective

Install and configure containerd as the container runtime for Kubernetes. Configure it to use systemd as the cgroup driver, which is required for kubelet compatibility.

## 🧠 Why This Matters

Kubernetes needs a container runtime to run containers. Containerd is:
- **Lightweight**: Industry-standard core container runtime
- **CRI-compliant**: Works seamlessly with Kubernetes
- **Production-ready**: Used by major cloud providers

---

## 📋 Tasks

### Task 2.1: Install Dependencies

Install required packages for repository management:

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

---

### Task 2.2: Add Docker Repository (for containerd)

Create directory for GPG keys:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Download and add Docker's GPG key:

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Set proper permissions:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Add Docker repository:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

---

### Task 2.3: Install containerd

Update package list and install:

```bash
sudo apt-get update
sudo apt-get install -y containerd.io
```

```bash
*** config.toml (Y/I/N/O/D/Z) [default=N] ? N
Choose the default option
```

**Verify installation:**
```bash
containerd --version
```

Expected output: Should show containerd version (e.g., `containerd containerd.io 1.7.x`)

---

### Task 2.4: Configure containerd

Create containerd configuration directory:

```bash
sudo mkdir -p /etc/containerd
```

Generate default configuration:

```bash
containerd config default | sudo tee /etc/containerd/config.toml
```

🔴 **CRITICAL**: Enable SystemdCgroup (required for kubelet):

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

**Verify the change:**
```bash
grep SystemdCgroup /etc/containerd/config.toml
```

Expected output: `SystemdCgroup = true`

---

### Task 2.5: Restart and Enable containerd

Restart the service to apply configuration:

```bash
sudo systemctl restart containerd
```

Enable containerd to start on boot:

```bash
sudo systemctl enable containerd
```

**Check service status:**
```bash
sudo systemctl status containerd
```

Expected output: Should show `active (running)` in green

Press `q` to exit the status view.

---

## ✅ Verification Checklist

Before proceeding, ensure:

- [ ] containerd is installed and version is displayed
- [ ] Configuration file exists at `/etc/containerd/config.toml`
- [ ] `SystemdCgroup = true` in the configuration
- [ ] containerd service is active and running
- [ ] containerd is enabled to start on boot

---

## 🔍 Troubleshooting

**Problem**: "Failed to start containerd.service"
- **Solution**: Check logs with `journalctl -xeu containerd.service`
- Verify configuration syntax: `containerd config dump`

**Problem**: SystemdCgroup not set to true
- **Solution**: Manually edit the file:
  ```bash
  sudo nano /etc/containerd/config.toml
  ```
  Find `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]`
  Set `SystemdCgroup = true`


---

**Ready?** Click **Continue** to proceed to Step 3! ➡️
