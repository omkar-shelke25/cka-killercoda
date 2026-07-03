# Configure cri-dockerd on a Node

**Official Kubernetes Documentation**:
- [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Network Plugin Requirements](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

## Context

Your team is preparing a Kubernetes node to support Docker-based workloads using cri-dockerd as the container runtime interface. A Debian installation package has already been placed on the node at `~/cri-dockerd.deb`.

You must ensure the node is correctly configured so that Kubernetes components can interact with the runtime without issues.

Docker is already installed and running on the system, but the CRI (Container Runtime Interface) adapter is not yet configured.

## Question

Install cri-dockerd from the provided `.deb` package, enable the cri-docker service, and ensure it is running.

Additionally, configure the system with the following required kernel and networking parameters:
- `net.bridge.bridge-nf-call-iptables` should be set to `1`
- `net.ipv6.conf.all.forwarding` should be set to `1`
- `net.ipv4.ip_forward` should be set to `1`
- `net.netfilter.nf_conntrack_max` should be set to `131072`

All parameter configurations must be made persistent by placing them in the file:
- `/etc/sysctl.d/99-kubernetes-cri.conf`

**Hint**: The `net.bridge.bridge-nf-call-iptables` parameter requires the `br_netfilter` kernel module to be loaded first.

---

## Solution

<details>
<summary>Click to view Solution</summary>
  
**Step 1: Verify the package exists**

```bash
ls -lh ~/cri-dockerd.deb
```

**Step 2: Install the cri-dockerd package**

```bash
sudo dpkg -i ~/cri-dockerd.deb
```

If there are dependency issues, fix them:

```bash
sudo apt-get install -f -y
```

**Step 3: Verify the installation**

```bash
which cri-dockerd
cri-dockerd --version
```

**Step 4: Enable and start the cri-docker service**

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

```bash
sudo systemctl status cri-docker.service
sudo systemctl status cri-docker.socket
sudo systemctl is-active cri-docker.socket
```

**Step 6: Load the br_netfilter module**

This module is required for the bridge iptables parameter to exist:

```bash
sudo modprobe br_netfilter
```

To make it persistent across reboots:

```bash
echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
```

**Step 7: Configure kernel parameters for persistence**

Create a sysctl configuration file for Kubernetes networking:

```bash
sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.ip_forward = 1
net.netfilter.nf_conntrack_max = 131072
EOF
```

**Step 8: Apply the kernel parameters**

Apply the parameters immediately without reboot:

```bash
sudo sysctl --system
```

Or apply the specific file:

```bash
sudo sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf
```

**Step 9: Verify the kernel parameters**

Check each parameter is set correctly:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv6.conf.all.forwarding
sysctl net.ipv4.ip_forward
sysctl net.netfilter.nf_conntrack_max
```

All should show the configured values.

**Step 10: Verify persistence**

Confirm the configuration file exists and will persist after reboot:

```bash
cat /etc/sysctl.d/99-kubernetes-cri.conf
```

**Step 11: Test the cri-dockerd socket**

Verify the CRI socket is accessible:

```bash
sudo ls -la /run/cri-dockerd.sock
```

If crictl is available, you can also test connectivity:

```bash
sudo crictl --runtime-endpoint unix:///run/cri-dockerd.sock version
```
</details>
