# 🎉 Mission Accomplished!

You have successfully **troubleshot and fixed the kube-apiserver static Pod** with incorrect CPU resource requests! 🚀


---
## 💬 Have a doubt?

🔗 **Discord Link:**
[https://killercoda.com/discord](https://killercoda.com/discord)

---

## 🧩 **Conceptual Summary**

### Static Pods

- **Static Pods**: Pods managed directly by kubelet on a specific node
- **Manifest location**: `/etc/kubernetes/manifests/` (default path)
- **No API server required**: Kubelet creates these Pods directly
- **Auto-recreation**: Kubelet watches the manifest directory and recreates Pods when files change

### Resource Requests and Limits

- **Requests**: Minimum guaranteed resources for a container
- **Limits**: Maximum resources a container can use
- **Scheduling**: Pods are scheduled only if nodes have sufficient resources to meet requests
- **QoS Classes**: Determined by requests and limits configuration

### How It Works Together

```
Static Pod Manifest
    ↓
/etc/kubernetes/manifests/kube-apiserver.yaml
    ↓
Kubelet watches directory
    ↓
Reads manifest and validates resources
    ↓
Checks node capacity (1000m CPU)
    ↓
Compares with Pod requests (200m CPU)
    ↓
✅ 200m < 1000m → Pod can be scheduled
❌ 4000m > 1000m → Pod cannot be scheduled
```

### 🧠 Conceptual Diagram

```md
Resource Scheduling Flow:
------------------------
1. Kubelet reads static Pod manifest
2. Extract resource requests (CPU: 200m, Memory: XXXMi)
3. Check node allocatable resources
4. Calculate: Available = Allocatable - (Sum of all Pod requests)
5. If Pod request ≤ Available → Schedule Pod
6. If Pod request > Available → Reject with "Insufficient resources"

Problem Scenario:
----------------
Node Capacity: 1000m (1 CPU core)
kube-apiserver request: 4000m (4 CPU cores)
Result: 4000m > 1000m = Cannot schedule ❌

Solution:
--------
Calculate 20% of 1000m = 200m
Update manifest: cpu: 200m
Result: 200m < 1000m = Can schedule ✅
```

## 💡 Real-World Use Cases

### Control Plane Resource Management
- **API server**: Handles all cluster API requests
- **Controller manager**: Runs cluster controllers
- **Scheduler**: Assigns Pods to nodes
- **etcd**: Stores cluster state

### Resource Planning
- **Small clusters**: 100-250m CPU per control plane component
- **Medium clusters**: 250-500m CPU per component
- **Large clusters**: 500m-1000m+ CPU per component
- **Resource overhead**: Reserve 10-20% for system processes

### Troubleshooting Scenarios
- **OOM kills**: Memory limits too low
- **CPU throttling**: Limits too restrictive
- **Failed scheduling**: Requests exceed node capacity
- **Node pressure**: Too many Pods consuming resources

## 📚 Static Pod Locations

### Default Paths
- **kubeadm clusters**: `/etc/kubernetes/manifests/`
- **Custom installations**: Defined in kubelet config `--pod-manifest-path`

### Control Plane Components (Static Pods)
```
/etc/kubernetes/manifests/
├── kube-apiserver.yaml
├── kube-controller-manager.yaml
├── kube-scheduler.yaml
└── etcd.yaml
```

### Kubelet Configuration
```yaml
# /var/lib/kubelet/config.yaml
staticPodPath: /etc/kubernetes/manifests
```

## 🔑 Resource Request Calculations

### CPU Units
- **1 CPU** = 1000 millicores (1000m)
- **0.5 CPU** = 500m
- **0.1 CPU** = 100m

### Common Calculations
```bash
# 20% of 1 CPU core
1000m × 0.20 = 200m

# 10% of 2 CPU cores
2000m × 0.10 = 200m

# 50% of 4 CPU cores
4000m × 0.50 = 2000m
```

### Memory Units
- **Ki** = Kibibyte (1024 bytes)
- **Mi** = Mebibyte (1024 Ki)
- **Gi** = Gibibyte (1024 Mi)
- **K** = Kilobyte (1000 bytes)
- **M** = Megabyte (1000 K)
- **G** = Gigabyte (1000 M)

## 🎯 QoS Classes

| QoS Class      | Requests | Limits | Description                              |
| -------------- | -------- | ------ | ---------------------------------------- |
| **Guaranteed** | Set      | Equal  | Requests = Limits for all resources      |
| **Burstable**  | Set      | Higher | Requests < Limits (or only requests set) |
| **BestEffort** | None     | None   | No requests or limits specified          |

### QoS Impact
- **Guaranteed**: Last to be evicted under resource pressure
- **Burstable**: Evicted after BestEffort Pods
- **BestEffort**: First to be evicted when node runs out of resources


🎯 **Excellent work!**

You've successfully mastered **troubleshooting static Pods and managing control plane resource requests**! 🚀

Keep sharpening your skills—your **CKA success** is on the horizon! 🌅  
**Outstanding performance, Kubernetes Engineer! 💪🐳**
