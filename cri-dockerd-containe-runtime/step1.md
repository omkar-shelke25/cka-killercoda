# 🧠 **CKA: Configure cri-dockerd on a Node**

📚 **Official Kubernetes Documentation**: 
- [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Network Plugin Requirements](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

### 🏢 **Context**

Your team is preparing a Kubernetes node to support Docker-based workloads using cri-dockerd as the container runtime interface. A Debian installation package has already been placed on the node at `~/cri-dockerd.deb`.

You must ensure the node is correctly configured so that Kubernetes components can interact with the runtime without issues.

Docker is already installed and running on the system, but the CRI (Container Runtime Interface) adapter is not yet configured.

### ❓ **Question**

Install cri-dockerd from the provided `.deb` package, enable the cri-docker service, and ensure it is running. 

Additionally, configure the system with the following required kernel and networking parameters: 
`net.bridge.bridge-nf-call-iptables` should be set to 1
`net.ipv6.conf.all.forwarding` should be set to 1,
`net.ipv4.ip_forward` should be set to 1
`net.netfilter.nf_conntrack_max` should be set to 131072. 

All parameter changes must persist across system reboots.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the package exists**

Check that the cri-dockerd package is available:
```bash
ls -lh ~/cri-dockerd.deb
```

**Step 2: Install the cri-dockerd package**

Install the package using dpkg:
```bash
sudo dpkg -i ~/cri-dockerd.deb
```

If there are dependency issues, fix them:
```bash
sudo apt-get install -f -y
```

**Step 3: Verify the installation**

Check that cri-dockerd binaries are installed:
```bash
which cri-dockerd
cri-dockerd --version
```

**Step 4: Enable and start the cri-docker service**

Enable the service to start on boot:
```bash
sudo systemctl enable cri-docker.service
sudo systemctl enable cri-docker.socket
```

Start the services:
```bash
sudo systemctl start cri-docker.service
sudo systemctl start cri-docker.socket
```

**Step 5: Verify the service is running**

Check the service status:
```bash
sudo systemctl status cri-docker.service
sudo systemctl status cri-docker.socket
```

Check if the socket is active:
```bash
sudo systemctl is-active cri-docker.socket
```

**Step 6: Configure kernel parameters for persistence**

Create a sysctl configuration file for Kubernetes networking:
```bash
sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.ip_forward = 1
net.netfilter.nf_conntrack_max = 131072
EOF
```

**Step 7: Apply the kernel parameters**

Apply the parameters immediately without reboot:
```bash
sudo sysctl --system
```

Alternatively, apply them directly:
```bash
sudo sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf
```

**Step 8: Verify the kernel parameters**

Check each parameter is set correctly:
```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv6.conf.all.forwarding
sysctl net.ipv4.ip_forward
sysctl net.netfilter.nf_conntrack_max
```

All should show the configured values.

**Step 9: Verify persistence**

Confirm the configuration file exists and will persist after reboot:
```bash
cat /etc/sysctl.d/99-kubernetes-cri.conf
```

**Step 10: Test the cri-dockerd socket**

Verify the CRI socket is accessible:
```bash
sudo ls -la /run/cri-dockerd.sock
```

You can also test basic connectivity (requires crictl):
```bash
# If crictl is available
sudo crictl --runtime-endpoint unix:///run/cri-dockerd.sock version
```


</details>
